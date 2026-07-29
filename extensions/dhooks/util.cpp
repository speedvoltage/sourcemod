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

#include "util.h"

void * GetObjectAddr(HookParamType type, unsigned int flags, void **params, size_t offset)
{
#ifdef  WIN32
	if (type == HookParamType_Object)
		return (void *)((intptr_t)params + offset);
#elif POSIX
	if (type == HookParamType_Object && !(flags & PASSFLAG_ODTOR)) //Objects are passed by rrefrence if they contain destructors.
		return (void *)((intptr_t)params + offset);
#endif
	return *(void **)((intptr_t)params + offset);

}

size_t GetStackParamOffset(HookParamsStruct *paramStruct, unsigned int index)
{
	assert(paramStruct->dg->params[index].custom_register == None);

	size_t offset = 0;
	for (unsigned int i = 0; i < index; i++)
	{
		// Only care for arguments on the stack before us.
		if (paramStruct->dg->params[i].custom_register != None)
			continue;

#ifndef WIN32
		if (paramStruct->dg->params[i].type == HookParamType_Object && (paramStruct->dg->params[i].flags & PASSFLAG_ODTOR)) //Passed by refrence
		{
			offset += sizeof(void *);
			continue;
		}
#endif
#ifdef KE_ARCH_X64
		offset += 8;
#else
		offset += paramStruct->dg->params[i].size;
#endif
	}
	return offset;
}

size_t GetRegisterParamOffset(HookParamsStruct *paramStruct, unsigned int index)
{
	// TODO: Fix this up and get a pointer to the CDetour
	assert(paramStruct->dg->params[index].custom_register != None);

	// Need to get the size of the stack arguments first. Register arguments are stored after them in the buffer.
	size_t stackSize = 0;
	for (int i = paramStruct->dg->params.size() - 1; i >= 0; i--)
	{
		if (paramStruct->dg->params[i].custom_register == None)
		{
#ifdef KE_ARCH_X64
			stackSize += 8;
#else
			stackSize += paramStruct->dg->params[i].size;
#endif
		}
	}

	size_t offset = stackSize;
	for (unsigned int i = 0; i < index; i++)
	{
		// Only care for arguments passed through a register as well before us.
		if (paramStruct->dg->params[i].custom_register == None)
			continue;

#ifdef KE_ARCH_X64
		offset += 8;
#else
		offset += paramStruct->dg->params[i].size;
#endif
	}
	return offset;
}

size_t GetParamOffset(HookParamsStruct *paramStruct, unsigned int index)
{
	if (paramStruct->dg->params[index].custom_register == None)
		return GetStackParamOffset(paramStruct, index);
	else
		return GetRegisterParamOffset(paramStruct, index);
}

size_t GetParamTypeSize(HookParamType type)
{
#ifdef KE_ARCH_X64
	switch (type)
	{
	case HookParamType_Int:
		return sizeof(int);
	case HookParamType_Bool:
		return sizeof(bool);
	case HookParamType_Float:
		return sizeof(float);
	default:
		return sizeof(void *);
	}
#else
	return sizeof(void *);
#endif
}

size_t GetParamsSize(DHooksCallback *dg)//Get the full size, this is for creating the STACK.
{
	size_t res = 0;

	for (int i = dg->params.size() - 1; i >= 0; i--)
	{
#ifdef KE_ARCH_X64
		res += 8;
#else
		res += dg->params.at(i).size;
#endif
	}

	return res;
}

bool DynamicHooks_ConvertParamTypeFrom(HookParamType type, DataType_t *result)
{
	switch (type)
	{
	case HookParamType_Int:
		*result = DATA_TYPE_INT;
		return true;
	case HookParamType_Bool:
		*result = DATA_TYPE_BOOL;
		return true;
	case HookParamType_Float:
		*result = DATA_TYPE_FLOAT;
		return true;
	case HookParamType_String:
		*result = DATA_TYPE_STRING;
		return true;
	case HookParamType_StringPtr:
	case HookParamType_CharPtr:
	case HookParamType_VectorPtr:
	case HookParamType_CBaseEntity:
	case HookParamType_ObjectPtr:
	case HookParamType_Edict:
		*result = DATA_TYPE_POINTER;
		return true;
	case HookParamType_Object:
		*result = DATA_TYPE_OBJECT;
		return true;
	default:
		return false;
	}
}

bool DynamicHooks_ConvertReturnTypeFrom(ReturnType type, DataType_t *result)
{
	switch (type)
	{
	case ReturnType_Void:
		*result = DATA_TYPE_VOID;
		return true;
	case ReturnType_Int:
		*result = DATA_TYPE_INT;
		return true;
	case ReturnType_Bool:
		*result = DATA_TYPE_BOOL;
		return true;
	case ReturnType_Float:
		*result = DATA_TYPE_FLOAT;
		return true;
	case ReturnType_String:
		*result = DATA_TYPE_STRING;
		return true;
	case ReturnType_StringPtr:
	case ReturnType_CharPtr:
	case ReturnType_VectorPtr:
	case ReturnType_CBaseEntity:
	case ReturnType_Edict:
		*result = DATA_TYPE_POINTER;
		return true;
	case ReturnType_Vector:
		*result = DATA_TYPE_OBJECT;
		return true;
	default:
		return false;
	}
}

Register_t DynamicHooks_ConvertRegisterFrom(PluginRegister reg)
{
	switch (reg)
	{
	case DHookRegister_Default:
		return None;

	case DHookRegister_AL:
		return AL;
	case DHookRegister_CL:
		return CL;
	case DHookRegister_DL:
		return DL;
	case DHookRegister_BL:
		return BL;
	case DHookRegister_AH:
		return AH;
	case DHookRegister_CH:
		return CH;
	case DHookRegister_DH:
		return DH;
	case DHookRegister_BH:
		return BH;

	case DHookRegister_EAX:
		return EAX;
	case DHookRegister_ECX:
		return ECX;
	case DHookRegister_EDX:
		return EDX;
	case DHookRegister_EBX:
		return EBX;
	case DHookRegister_ESP:
		return ESP;
	case DHookRegister_EBP:
		return EBP;
	case DHookRegister_ESI:
		return ESI;
	case DHookRegister_EDI:
		return EDI;

	case DHookRegister_XMM0:
		return XMM0;
	case DHookRegister_XMM1:
		return XMM1;
	case DHookRegister_XMM2:
		return XMM2;
	case DHookRegister_XMM3:
		return XMM3;
	case DHookRegister_XMM4:
		return XMM4;
	case DHookRegister_XMM5:
		return XMM5;
	case DHookRegister_XMM6:
		return XMM6;
	case DHookRegister_XMM7:
		return XMM7;

	case DHookRegister_ST0:
		return ST0;
	}

	return None;
}
