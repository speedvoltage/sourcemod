/**
 * vim: set ts=4 :
 * =============================================================================
 * SourceMod Dynamic Hooks Extension
 * Copyright (C) 2012-2021 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

#include "dynhooks_sourcepawn.h"
#include "util.h"
#include <memory>

#ifdef KE_WINDOWS
#ifdef DYNAMICHOOKS_x86_64
#include "conventions/x86_64MicrosoftDefault.h"
typedef x86_64MicrosoftDefault x86_64DetourCall;
#else
#include "conventions/x86MsCdecl.h"
#include "conventions/x86MsThiscall.h"
#include "conventions/x86MsStdcall.h"
#include "conventions/x86MsFastcall.h"
typedef x86MsCdecl x86DetourCdecl;
typedef x86MsThiscall x86DetourThisCall;
typedef x86MsStdcall x86DetourStdCall;
typedef x86MsFastcall x86DetourFastCall;
#endif
#elif defined KE_LINUX
#ifdef DYNAMICHOOKS_x86_64
#include "conventions/x86_64SystemVDefault.h"
typedef x86_64SystemVDefault x86_64DetourCall;
#else
#include "conventions/x86GccCdecl.h"
#include "conventions/x86GccThiscall.h"
#include "conventions/x86MsStdcall.h"
#include "conventions/x86MsFastcall.h"
typedef x86GccCdecl x86DetourCdecl;
typedef x86GccThiscall x86DetourThisCall;
// Uhm, stdcall on linux?
typedef x86MsStdcall x86DetourStdCall;
// Uhumm, fastcall on linux?
typedef x86MsFastcall x86DetourFastCall;
#endif
#else
#error "Unsupported platform."
#endif

namespace
{
	size_t GetArgumentTypeOffset(CallingConvention callConv)
	{
		if (callConv != CallConv_THISCALL)
			return 0;
#if defined(DYNAMICHOOKS_x86_64) || defined(KE_LINUX)
		return 1;
#else
		return 0;
#endif
	}

	size_t GetArgumentPointerOffset(CallingConvention callConv)
	{
		return callConv == CallConv_THISCALL ? 1 : 0;
	}
}

// Keep a map of detours and their registered plugin callbacks.
DetourMap g_pPreDetours;
DetourMap g_pPostDetours;

struct DeferredDetourRemoval
{
	HookType_t hookType;
	CHook *detour;
	CDynamicHooksSourcePawn *wrapper;
};

std::vector<DeferredDetourRemoval> g_DeferredDetourRemovals;
bool g_DetourRemovalFrameHookRegistered;

void UnhookFunction(HookType_t hookType, CHook *pDetour)
{
#if defined( DHOOKS_DYNAMIC_DETOUR )
	CHookManager *pDetourManager = GetHookManager();
	pDetour->RemoveCallback(hookType, (HookHandlerFn *)(void *)&HandleDetour);
	if (!pDetour->AreCallbacksRegistered())
		pDetourManager->UnhookFunction(pDetour->m_pFunc);
#endif
}

void ProcessDeferredDetourRemovals(bool)
{
#if defined( DHOOKS_DYNAMIC_DETOUR )
	if (g_DeferredDetourRemovals.empty())
		return;

	std::vector<DeferredDetourRemoval> removals;
	removals.swap(g_DeferredDetourRemovals);

	for (const DeferredDetourRemoval &removal : removals)
	{
		DetourMap *map =
			removal.hookType == HOOKTYPE_PRE
				? &g_pPreDetours
				: &g_pPostDetours;
		DetourMap::Result res = map->find(removal.detour);
		if (!res.found())
			continue;

		PluginCallbackList *wrappers = res->value;
		for (size_t i = 0; i < wrappers->size(); i++)
		{
			if (wrappers->at(i) != removal.wrapper)
				continue;
			delete removal.wrapper;
			wrappers->erase(wrappers->begin() + i);
			break;
		}

		if (!wrappers->empty())
			continue;
		delete wrappers;
		map->remove(res);
		UnhookFunction(removal.hookType, removal.detour);
	}
#endif
}

bool QueueDetourRemoval(
	HookType_t hookType,
	CHook *pDetour,
	CDynamicHooksSourcePawn *pWrapper)
{
#if defined( DHOOKS_DYNAMIC_DETOUR )
	if (!pWrapper->enabled)
		return false;
	pWrapper->enabled = false;
	g_DeferredDetourRemovals.push_back({hookType, pDetour, pWrapper});
	return true;
#else
	return false;
#endif
}

void StartDetourRemovalFrameHook()
{
#if defined( DHOOKS_DYNAMIC_DETOUR )
	if (g_DetourRemovalFrameHookRegistered)
		return;
	smutils->AddGameFrameHook(ProcessDeferredDetourRemovals);
	g_DetourRemovalFrameHookRegistered = true;
#endif
}

void StopDetourRemovalFrameHook()
{
#if defined( DHOOKS_DYNAMIC_DETOUR )
	if (!g_DetourRemovalFrameHookRegistered)
		return;
	smutils->RemoveGameFrameHook(ProcessDeferredDetourRemovals);
	g_DetourRemovalFrameHookRegistered = false;
#endif
}

bool AddDetourPluginHook(HookType_t hookType, CHook *pDetour, HookSetup *setup, IPluginFunction *pCallback)
{
#if defined( DHOOKS_DYNAMIC_DETOUR )
	DetourMap *map;
	if (hookType == HOOKTYPE_PRE)
		map = &g_pPreDetours;
	else
		map = &g_pPostDetours;

	// See if we already have this detour in our list.
	PluginCallbackList *wrappers;
	DetourMap::Insert f = map->findForAdd(pDetour);
	if (f.found())
	{
		wrappers = f->value;
	}
	else
	{
		// Create a vector to store all the plugin callbacks in.
		wrappers = new PluginCallbackList;
		if (!map->add(f, pDetour, wrappers))
		{
			delete wrappers;
			UnhookFunction(hookType, pDetour);
			return false;
		}
	}

	// Add the plugin callback to the detour list.
	CDynamicHooksSourcePawn *pWrapper = new CDynamicHooksSourcePawn(setup, pDetour, pCallback, pCallback->GetParentRuntime()->FindPubvarByName("__Int64_Address__", nullptr) == SP_ERROR_NONE, hookType == HOOKTYPE_POST);
	wrappers->push_back(pWrapper);

	return true;
#else
	return false;
#endif
}

bool RemoveDetourPluginHook(HookType_t hookType, CHook *pDetour, IPluginFunction *pCallback)
{
#if defined( DHOOKS_DYNAMIC_DETOUR )
	DetourMap *map;
	if (hookType == HOOKTYPE_PRE)
		map = &g_pPreDetours;
	else
		map = &g_pPostDetours;

	DetourMap::Result res = map->find(pDetour);
	if (!res.found())
		return false;

	// Remove the plugin's callback
	bool bRemoved = false;
	PluginCallbackList *wrappers = res->value;
	for (int i = wrappers->size()-1; i >= 0 ; i--)
	{
		CDynamicHooksSourcePawn *pWrapper = wrappers->at(i);
		if (pWrapper->plugin_callback == pCallback)
			bRemoved =
				QueueDetourRemoval(hookType, pDetour, pWrapper) ||
				bRemoved;
	}

	return bRemoved;
#else
	return false;
#endif
}

void RemoveAllCallbacksForContext(HookType_t hookType, DetourMap *map, IPluginContext *pContext)
{
#if defined( DHOOKS_DYNAMIC_DETOUR )
	PluginCallbackList *wrappers;
	CDynamicHooksSourcePawn *pWrapper;
	DetourMap::iterator it = map->iter();
	// Run through all active detours we added.
	for (; !it.empty(); it.next())
	{
		wrappers = it->value;
		// See if there are callbacks of this plugin context registered
		// and remove them.
		for (int i = wrappers->size() - 1; i >= 0; i--)
		{
			pWrapper = wrappers->at(i);
			if (!pWrapper->enabled)
				continue;
			if (pWrapper->plugin_callback->GetParentRuntime()->GetDefaultContext() != pContext)
				continue;

			QueueDetourRemoval(hookType, it->key, pWrapper);
		}
	}
#endif
}

void RemoveAllCallbacksForContext(IPluginContext *pContext)
{
#if defined( DHOOKS_DYNAMIC_DETOUR )
	RemoveAllCallbacksForContext(HOOKTYPE_PRE, &g_pPreDetours, pContext);
	RemoveAllCallbacksForContext(HOOKTYPE_POST, &g_pPostDetours, pContext);
#endif
}

void CleanupDetours(HookType_t hookType, DetourMap *map)
{
#if defined( DHOOKS_DYNAMIC_DETOUR )
	PluginCallbackList *wrappers;
	CDynamicHooksSourcePawn *pWrapper;
	DetourMap::iterator it = map->iter();
	// Run through all active detours we added.
	for (; !it.empty(); it.next())
	{
		wrappers = it->value;
		// Remove all callbacks
		for (int i = wrappers->size() - 1; i >= 0; i--)
		{
			pWrapper = wrappers->at(i);
			delete pWrapper;
		}

		// Unhook the function
		delete wrappers;
		UnhookFunction(hookType, it->key);
	}
	map->clear();
#endif
}

void CleanupDetours()
{
#if defined( DHOOKS_DYNAMIC_DETOUR )
	g_DeferredDetourRemovals.clear();
	CleanupDetours(HOOKTYPE_PRE, &g_pPreDetours);
	CleanupDetours(HOOKTYPE_POST, &g_pPostDetours);
	GetHookManager()->UnhookAllFunctions();
#endif
}

#if defined( DHOOKS_DYNAMIC_DETOUR )
ICallingConvention *ConstructCallingConvention(HookSetup *setup, std::string *error)
{
	// Convert function parameter types into DynamicHooks structures.
	std::vector<DataTypeSized_t> vecArgTypes;
	for (size_t i = 0; i < setup->params.size(); i++)
	{
		ParamInfo &info = setup->params[i];
		if (info.flags != PASSFLAG_BYVAL)
		{
			if (error)
				*error = "Pass flags are not supported for detour parameters.";
			return nullptr;
		}
		DataTypeSized_t type;
		if (!DynamicHooks_ConvertParamTypeFrom(info.type, &type.type))
		{
			if (error)
				*error = "Unsupported parameter type.";
			return nullptr;
		}
		type.size = info.size;
		type.custom_register = info.custom_register;
		vecArgTypes.push_back(type);
	}

	DataTypeSized_t returnType;
	if (!DynamicHooks_ConvertReturnTypeFrom(setup->returnType, &returnType.type))
	{
		if (error)
			*error = "Unsupported return type.";
		return nullptr;
	}
	returnType.size = 0;
	// TODO: Add support for a custom return register.
	returnType.custom_register = None;

#ifdef DYNAMICHOOKS_x86_64
	if (setup->callConv == CallConv_THISCALL) {
		DataTypeSized_t type;
		type.type = DATA_TYPE_POINTER;
		type.size = GetDataTypeSize(type, sizeof(void*));
#ifdef WIN32
		type.custom_register = RCX;
#else
		type.custom_register = None;
#endif
		vecArgTypes.insert(vecArgTypes.begin(), type);
	}
#endif

	ICallingConvention *pCallConv = nullptr;
	switch (setup->callConv)
	{
#ifdef DYNAMICHOOKS_x86_64
	case CallConv_THISCALL:
	case CallConv_CDECL:
	case CallConv_STDCALL:
	case CallConv_FASTCALL:
		pCallConv = new x86_64DetourCall(vecArgTypes, returnType);
		break;
#else
	case CallConv_CDECL:
		pCallConv = new x86DetourCdecl(vecArgTypes, returnType);
		break;
	case CallConv_THISCALL:
		pCallConv = new x86DetourThisCall(vecArgTypes, returnType);
		break;
	case CallConv_STDCALL:
		pCallConv = new x86DetourStdCall(vecArgTypes, returnType);
		break;
	case CallConv_FASTCALL:
		pCallConv = new x86DetourFastCall(vecArgTypes, returnType);
		break;
#endif
	default:
		smutils->LogError(myself, "Unknown calling convention %d.", setup->callConv);
		break;
	}

	if (pCallConv && !pCallConv->IsValid())
	{
		if (error)
			*error = pCallConv->GetError();
		delete pCallConv;
		pCallConv = nullptr;
	}
	else if (!pCallConv && error && error->empty())
	{
		*error = "Unsupported calling convention.";
	}

	return pCallConv;
}
#endif

bool CallingConventionsMatch(ICallingConvention *left, ICallingConvention *right)
{
	if (!left || !right ||
		left->m_returnType.type != right->m_returnType.type ||
		left->m_returnType.size != right->m_returnType.size ||
		left->m_returnType.custom_register != right->m_returnType.custom_register ||
		left->m_vecArgTypes.size() != right->m_vecArgTypes.size() ||
		left->GetPopSize() != right->GetPopSize() ||
		left->GetArgStackSize() != right->GetArgStackSize() ||
		left->GetArgRegisterSize() != right->GetArgRegisterSize() ||
		left->GetRegisters() != right->GetRegisters())
	{
		return false;
	}

	for (size_t i = 0; i < left->m_vecArgTypes.size(); i++)
	{
		const DataTypeSized_t &leftType = left->m_vecArgTypes[i];
		const DataTypeSized_t &rightType = right->m_vecArgTypes[i];
		if (leftType.type != rightType.type ||
			leftType.size != rightType.size ||
			leftType.custom_register != rightType.custom_register)
		{
			return false;
		}
	}

	return true;
}

// Some arguments might be optimized to be passed in registers instead of the stack.
bool UpdateRegisterArgumentSizes(CHook* pDetour, HookSetup *setup)
{
	if (!pDetour || !pDetour->m_pCallingConvention)
		return false;

	// The registers the arguments are passed in might not be the same size as the actual parameter type.
	// Update the type info to the size of the register that's now holding that argument,
	// so we can copy the whole value.
	ICallingConvention* callingConvention = pDetour->m_pCallingConvention;
	std::vector<DataTypeSized_t> &argTypes = callingConvention->m_vecArgTypes;
	size_t typeOffset = GetArgumentTypeOffset(setup->callConv);
	if (argTypes.size() != setup->params.size() + typeOffset)
		return false;

	DataType_t returnType;
	if (!DynamicHooks_ConvertReturnTypeFrom(setup->returnType, &returnType) ||
		callingConvention->m_returnType.type != returnType)
		return false;

	for (size_t i = 0; i < setup->params.size(); i++)
	{
		DataTypeSized_t &argType = argTypes[i + typeOffset];
		ParamInfo &param = setup->params[i];
		DataType_t paramType;
		if (!DynamicHooks_ConvertParamTypeFrom(param.type, &paramType) ||
			argType.type != paramType ||
			argType.size != param.size ||
			(param.custom_register != None &&
			 param.custom_register != argType.custom_register))
		{
			return false;
		}
		if (argType.custom_register == None)
			continue;

		CRegister *reg = pDetour->m_pRegisters->GetRegister(argType.custom_register);
		if (!reg)
			return false;

#ifndef DYNAMICHOOKS_x86_64
		param.custom_register = argType.custom_register;
		argType.size = reg->m_iSize;
		param.size = reg->m_iSize;
#endif
	}

	return true;
}

// Central handler for all detours. Heart of the detour support.
ReturnAction_t HandleDetour(HookType_t hookType, CHook* pDetour)
{
	// Can't call into SourcePawn offthread.
	if (g_MainThreadId != std::this_thread::get_id())
		return ReturnAction_Ignored;

	DetourMap *map;
	if (hookType == HOOKTYPE_PRE)
		map = &g_pPreDetours;
	else
		map = &g_pPostDetours;

	// Find the callback list for this detour.
	DetourMap::Result r = map->find(pDetour);
	if (!r.found())
		return ReturnAction_Ignored;

	// List of all callbacks.
	PluginCallbackList callbacks = *r->value;

	HookReturnStruct *returnStruct = NULL;
	Handle_t rHndl = BAD_HANDLE;

	HookParamsStruct *paramStruct = NULL;
	Handle_t pHndl = BAD_HANDLE;

	// Keep a copy of the last return value if some plugin wants to override or supercede the function.
	ReturnAction_t finalRet = ReturnAction_Ignored;
	size_t returnSize = pDetour->m_pCallingConvention->m_returnType.size;
	std::unique_ptr<uint8_t[]> finalRetBuf;
	if (returnSize > 0)
	{
		finalRetBuf = std::make_unique<uint8_t[]>(returnSize);
		memset(finalRetBuf.get(), 0, returnSize);
	}

	// Call all the plugin functions..
	for (CDynamicHooksSourcePawn *pWrapper : callbacks)
	{
		if (!pWrapper->enabled)
			continue;
		IPluginFunction *pCallback = pWrapper->plugin_callback;

		// Create a seperate buffer for changed return values for this plugin.
		// We update the finalRet above if the tempRet is higher than the previous ones in the callback list.
		ReturnAction_t tempRet = ReturnAction_Ignored;
		std::unique_ptr<uint8_t[]> tempRetBuf;
		if (returnSize > 0)
		{
			tempRetBuf = std::make_unique<uint8_t[]>(returnSize);
			memset(tempRetBuf.get(), 0, returnSize);
		}

		// Find the this pointer for thiscalls.
		// Don't even try to load it if the plugin doesn't care and set it to be ignored.
		if (pWrapper->callConv == CallConv_THISCALL && pWrapper->thisType != ThisPointer_Ignore)
		{
			// The this pointer is implicitly always the first argument.
			auto thisAddr = pDetour->GetArgument<void *>(0);
			if (pWrapper->thisType == ThisPointer_CBaseEntity) {
				if (thisAddr == nullptr) {
					pWrapper->plugin_callback->PushCell(-1);
				} else {
					pWrapper->plugin_callback->PushCell(gamehelpers->EntityToBCompatRef((CBaseEntity *)thisAddr));
				}
			} else {
				if (pWrapper->int64_address) {
					std::int64_t addr = reinterpret_cast<std::int64_t>(thisAddr);
					pWrapper->plugin_callback->PushArray(reinterpret_cast<cell_t*>(&addr), 2);
				} else {
					pWrapper->plugin_callback->PushCell(
						static_cast<cell_t>(reinterpret_cast<uintptr_t>(thisAddr)));
				}
			}
		}

		// Create the structure for plugins to change/get the return value if the function returns something.
		if (pWrapper->returnType != ReturnType_Void)
		{
			// Create a handle for the return value to pass to the plugin callback.
			returnStruct = pWrapper->GetReturnStruct();
			HandleError err;
			rHndl = handlesys->CreateHandle(g_HookReturnHandle, returnStruct, pCallback->GetParentRuntime()->GetDefaultContext()->GetIdentity(), myself->GetIdentity(), &err);
			if (!rHndl)
			{
				pCallback->Cancel();
				pCallback->GetParentRuntime()->GetDefaultContext()->BlamePluginError(pCallback, "Error creating ReturnHandle in preparation to call hook callback. (error %d)", err);

				if (returnStruct)
					delete returnStruct;

				// Don't call more callbacks. They will probably fail too.
				break;
			}
			pCallback->PushCell(rHndl);
		}

		// Create the structure for plugins to access the function arguments if it has some.
		if (!pWrapper->params.empty())
		{
			paramStruct = pWrapper->GetParamStruct();
			if (!paramStruct)
			{
				pCallback->Cancel();
				pCallback->GetParentRuntime()->GetDefaultContext()->BlamePluginError(
					pCallback,
					"Failed to marshal detour parameters.");
				if (rHndl)
				{
					HandleSecurity sec(
						pCallback->GetParentRuntime()->GetDefaultContext()->GetIdentity(),
						myself->GetIdentity());
					handlesys->FreeHandle(rHndl, &sec);
					rHndl = BAD_HANDLE;
				}
				break;
			}
			HandleError err;
			pHndl = handlesys->CreateHandle(g_HookParamsHandle, paramStruct, pCallback->GetParentRuntime()->GetDefaultContext()->GetIdentity(), myself->GetIdentity(), &err);
			if (!pHndl)
			{
				pCallback->Cancel();
				pCallback->GetParentRuntime()->GetDefaultContext()->BlamePluginError(pCallback, "Error creating ThisHandle in preparation to call hook callback. (error %d)", err);

				// Don't leak our own handles here! Free the return struct if we fail during the argument marshalling.
				if (rHndl)
				{
					HandleSecurity sec(pCallback->GetParentRuntime()->GetDefaultContext()->GetIdentity(), myself->GetIdentity());
					handlesys->FreeHandle(rHndl, &sec);
					rHndl = BAD_HANDLE;
				}

				if (paramStruct)
					delete paramStruct;

				// Don't call more callbacks. They will probably fail too.
				break;
			}
			pCallback->PushCell(pHndl);
		}

		// Run the plugin callback.
		cell_t result = (cell_t)MRES_Ignored;
#if defined(DYNAMICHOOKS_x86_64) && defined(KE_LINUX)
		pDetour->m_pCallingConvention->SaveCallArguments(pDetour->m_pRegisters);
		if (hookType == HOOKTYPE_POST && returnSize > 0)
			pDetour->m_pCallingConvention->SaveReturnValue(pDetour->m_pRegisters);
#endif
		pCallback->Execute(&result);
#if defined(DYNAMICHOOKS_x86_64) && defined(KE_LINUX)
		if (hookType == HOOKTYPE_POST && returnSize > 0)
			pDetour->m_pCallingConvention->RestoreReturnValue(pDetour->m_pRegisters);
		pDetour->m_pCallingConvention->RestoreCallArguments(pDetour->m_pRegisters);
#endif

		switch ((MRESReturn)result)
		{
		case MRES_Handled:
			tempRet = ReturnAction_Handled;
			break;
		case MRES_ChangedHandled:
			tempRet = ReturnAction_Handled;
			// Copy the changed parameter values from the plugin's parameter structure back into the actual detour arguments.
			pWrapper->UpdateParamsFromStruct(paramStruct);
			break;
		case MRES_ChangedOverride:
		case MRES_Override:
		case MRES_Supercede:
			// See if this function returns something we should override.
			if (pWrapper->returnType != ReturnType_Void)
			{
				// Make sure the plugin provided a new return value. Could be an oversight if MRES_ChangedOverride 
				// is called without the return value actually being changed.
				if (!returnStruct->isChanged)
				{
					//Throw an error if no override was set
					tempRet = ReturnAction_Ignored;
					pCallback->GetParentRuntime()->GetDefaultContext()->BlamePluginError(pCallback, "Tried to override return value without return value being set");
					break;
				}

				const void *returnSource = nullptr;
				size_t sourceSize = 0;
				void *pointerValue = returnStruct->newResult;
				switch (pWrapper->returnType)
				{
				case ReturnType_String:
					returnSource = returnStruct->newResult;
					sourceSize = sizeof(string_t);
					break;
				case ReturnType_Int:
					returnSource = returnStruct->newResult;
					sourceSize = sizeof(int);
					break;
				case ReturnType_Bool:
					returnSource = returnStruct->newResult;
					sourceSize = sizeof(bool);
					break;
				case ReturnType_Float:
					returnSource = returnStruct->newResult;
					sourceSize = sizeof(float);
					break;
				case ReturnType_Vector:
					returnSource = returnStruct->newResult;
					sourceSize = sizeof(SDKVector);
					break;
				default:
					returnSource = &pointerValue;
					sourceSize = sizeof(pointerValue);
					break;
				}

				if (!returnSource || !tempRetBuf)
				break;
				if (sourceSize > returnSize)
					sourceSize = returnSize;
				memcpy(tempRetBuf.get(), returnSource, sourceSize);
			}

			// Store if the plugin wants the original function to be called.
			if (result == MRES_Supercede)
				tempRet = ReturnAction_Supercede;
			else
				tempRet = ReturnAction_Override;

			// Copy the changed parameter values from the plugin's parameter structure back into the actual detour arguments.
			if (result == MRES_ChangedOverride)
				pWrapper->UpdateParamsFromStruct(paramStruct);
			break;
		default:
			tempRet = ReturnAction_Ignored;
			break;
		}

		// Prioritize the actions. 
		if (finalRet <= tempRet)
		{
			// Copy the action and return value.
			finalRet = tempRet;
			if (returnSize > 0)
				memcpy(finalRetBuf.get(), tempRetBuf.get(), returnSize);
		}

		// Free the handles again.
		HandleSecurity sec(pCallback->GetParentRuntime()->GetDefaultContext()->GetIdentity(), myself->GetIdentity());
		if (returnStruct)
		{
			handlesys->FreeHandle(rHndl, &sec);
		}
		if (paramStruct)
		{
			handlesys->FreeHandle(pHndl, &sec);
		}
	}

	// If we want to use our own return value, write it back.
	if (finalRet >= ReturnAction_Override && returnSize > 0)
	{
		void* pPtr = pDetour->m_pCallingConvention->GetReturnPtr(pDetour->m_pRegisters);
		memcpy(pPtr, finalRetBuf.get(), pDetour->m_pCallingConvention->m_returnType.size);
		pDetour->m_pCallingConvention->ReturnPtrChanged(pDetour->m_pRegisters, pPtr);
	}

	return finalRet;
}

CDynamicHooksSourcePawn::CDynamicHooksSourcePawn(HookSetup *setup, CHook *pDetour, IPluginFunction *pCallback, bool int64_addr, bool post)
{
	this->params = setup->params;
	this->offset = -1;
	this->returnFlag = setup->returnFlag;
	this->returnType = setup->returnType;
	this->post = post;
	this->plugin_callback = pCallback;
	this->entity = -1;
	this->thisType = setup->thisType;
	this->hookType = setup->hookType;
	this->m_pDetour = pDetour;
	this->callConv = setup->callConv;
	this->int64_address = int64_addr;
	this->thisFuncCallConv = setup->callConv;
	this->enabled = true;
#ifdef DYNAMICHOOKS_x86_64
	size_t typeOffset = GetArgumentTypeOffset(this->callConv);
	std::vector<DataTypeSized_t> &argTypes =
		pDetour->m_pCallingConvention->m_vecArgTypes;
	if (argTypes.size() == this->params.size() + typeOffset)
	{
		for (size_t i = 0; i < this->params.size(); i++)
			this->params[i].custom_register =
				argTypes[i + typeOffset].custom_register;
	}
#endif
}

HookReturnStruct *CDynamicHooksSourcePawn::GetReturnStruct()
{
	// Create buffers to store the return value of the function.
	HookReturnStruct *res = new HookReturnStruct();
	res->isChanged = false;
	res->type = this->returnType;
	res->orgResult = NULL;
	res->newResult = NULL;

	// Copy the actual function's return value too for post hooks.
	if (this->post)
	{
		switch (this->returnType)
		{
		case ReturnType_String:
			res->orgResult = malloc(sizeof(string_t));
			res->newResult = malloc(sizeof(string_t));
			*(string_t *)res->orgResult = m_pDetour->GetReturnValue<string_t>();
			break;
		case ReturnType_Int:
			res->orgResult = malloc(sizeof(int));
			res->newResult = malloc(sizeof(int));
			*(int *)res->orgResult = m_pDetour->GetReturnValue<int>();
			break;
		case ReturnType_Bool:
			res->orgResult = malloc(sizeof(bool));
			res->newResult = malloc(sizeof(bool));
			*(bool *)res->orgResult = m_pDetour->GetReturnValue<bool>();
			break;
		case ReturnType_Float:
			res->orgResult = malloc(sizeof(float));
			res->newResult = malloc(sizeof(float));
			*(float *)res->orgResult = m_pDetour->GetReturnValue<float>();
			break;
		case ReturnType_Vector:
		{
			res->orgResult = malloc(sizeof(SDKVector));
			res->newResult = malloc(sizeof(SDKVector));
			SDKVector vec = m_pDetour->GetReturnValue<SDKVector>();
			*(SDKVector *)res->orgResult = vec;
			break;
		}
		default:
			res->orgResult = m_pDetour->GetReturnValue<void *>();
			break;
		}
	}
	// Pre hooks don't have access to the return value yet - duh.
	// Just create the buffers for overridden values.
	// TODO: Strip orgResult malloc.
	else
	{
		switch (this->returnType)
		{
		case ReturnType_String:
			res->orgResult = malloc(sizeof(string_t));
			res->newResult = malloc(sizeof(string_t));
			*(string_t *)res->orgResult = NULL_STRING;
			break;
		case ReturnType_Vector:
			res->orgResult = malloc(sizeof(SDKVector));
			res->newResult = malloc(sizeof(SDKVector));
			*(SDKVector *)res->orgResult = SDKVector();
			break;
		case ReturnType_Int:
			res->orgResult = malloc(sizeof(int));
			res->newResult = malloc(sizeof(int));
			*(int *)res->orgResult = 0;
			break;
		case ReturnType_Bool:
			res->orgResult = malloc(sizeof(bool));
			res->newResult = malloc(sizeof(bool));
			*(bool *)res->orgResult = false;
			break;
		case ReturnType_Float:
			res->orgResult = malloc(sizeof(float));
			res->newResult = malloc(sizeof(float));
			*(float *)res->orgResult = 0.0;
			break;
		}
	}

	return res;
}

HookParamsStruct *CDynamicHooksSourcePawn::GetParamStruct()
{
	// Save argument values of detoured function.
	HookParamsStruct *params = new HookParamsStruct();
	params->dg = this;
	
	ICallingConvention* callingConvention = m_pDetour->m_pCallingConvention;
	size_t stackSize = callingConvention->GetArgStackSize();
	size_t paramsSize = stackSize + callingConvention->GetArgRegisterSize();
	std::vector<DataTypeSized_t> &argTypes = callingConvention->m_vecArgTypes;
	size_t typeOffset = GetArgumentTypeOffset(callConv);
	size_t pointerOffset = GetArgumentPointerOffset(callConv);
	size_t numArgs = this->params.size();
	if (argTypes.size() != numArgs + typeOffset)
	{
		delete params;
		return nullptr;
	}

	// Create space for original parameters and changes plugins might do.
	params->orgParams = (void **)malloc(paramsSize);
	params->newParams = (void **)malloc(paramsSize);
	params->isChanged = (bool *)malloc(numArgs * sizeof(bool));

	// Save old stack parameters.
	if (stackSize > 0)
	{
		void *pArgPtr = m_pDetour->m_pCallingConvention->GetStackArgumentPtr(m_pDetour->m_pRegisters);
		memcpy(params->orgParams, pArgPtr, stackSize);
	}

	memset(params->newParams, 0, paramsSize);
	memset(params->isChanged, false, numArgs * sizeof(bool));

	// Save the old parameters passed in a register.
	size_t offset = stackSize;
	for (size_t i = 0; i < numArgs; i++)
	{
		size_t typeIndex = i + typeOffset;
		size_t pointerIndex = i + pointerOffset;
		// We already saved the stack arguments.
		if (argTypes[typeIndex].custom_register == None)
			continue;

#ifdef DYNAMICHOOKS_x86_64
		size_t size = 8;
#else
		size_t size = argTypes[typeIndex].size;
#endif
		// Register argument values are saved after all stack arguments in this buffer.
		void *paramAddr = (void *)((intptr_t)params->orgParams + offset);
		void *regAddr = callingConvention->GetArgumentPtr(pointerIndex, m_pDetour->m_pRegisters);
		memcpy(paramAddr, regAddr, size);
		offset += size;
	}

	return params;
}

void CDynamicHooksSourcePawn::UpdateParamsFromStruct(HookParamsStruct *params)
{
	// Function had no params to update now.
	if (!params)
		return;

	ICallingConvention* callingConvention = m_pDetour->m_pCallingConvention;
	size_t stackSize = callingConvention->GetArgStackSize();
	std::vector<DataTypeSized_t> &argTypes = callingConvention->m_vecArgTypes;
	size_t typeOffset = GetArgumentTypeOffset(callConv);
	size_t pointerOffset = GetArgumentPointerOffset(callConv);
	size_t numArgs = this->params.size();
	if (argTypes.size() != numArgs + typeOffset)
		return;

	size_t stackOffset = 0;
	// Values of arguments stored in registers are saved after the stack arguments.
	size_t registerOffset = stackSize;
	size_t offset;
	for (size_t i = 0; i < numArgs; i++)
	{
		size_t typeIndex = i + typeOffset;
		size_t pointerIndex = i + pointerOffset;
#ifdef DYNAMICHOOKS_x86_64
		size_t size = 8;
#else
		size_t size = argTypes[typeIndex].size;
#endif
		// Only have to copy something if the plugin changed this parameter.
		if (params->isChanged[i])
		{
			// Get the offset of this argument in the linear buffer. Register argument values are placed after all stack arguments.
			offset = argTypes[typeIndex].custom_register == None ? stackOffset : registerOffset;

			void *paramAddr = (void *)((intptr_t)params->newParams + offset);
			void *stackAddr = callingConvention->GetArgumentPtr(pointerIndex, m_pDetour->m_pRegisters);
			memcpy(stackAddr, paramAddr, size);
			callingConvention->ArgumentPtrChanged(
				static_cast<unsigned int>(pointerIndex),
				m_pDetour->m_pRegisters,
				stackAddr);
		}

		// Keep track of the seperate stack and register arguments.
		if (argTypes[typeIndex].custom_register == None) {
#ifdef DYNAMICHOOKS_x86_64
			stackOffset += 8;
#else
			stackOffset += size;
#endif
		}
		else {
#ifdef DYNAMICHOOKS_x86_64
			registerOffset += 8;
#else
			registerOffset += size;
#endif
		}
	}
}
