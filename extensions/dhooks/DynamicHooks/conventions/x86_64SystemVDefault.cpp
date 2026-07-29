/**
* =============================================================================
* DynamicHooks-x86_64
* Copyright (C) 2024 Benoist "Kenzzer" André. All rights reserved.
* Copyright (C) 2024 AlliedModders LLC.  All rights reserved.
* =============================================================================
*
* This software is provided 'as-is', without any express or implied warranty.
* In no event will the authors be held liable for any damages arising from 
* the use of this software.
* 
* Permission is granted to anyone to use this software for any purpose, 
* including commercial applications, and to alter it and redistribute it 
* freely, subject to the following restrictions:
*
* 1. The origin of this software must not be misrepresented; you must not 
* claim that you wrote the original software. If you use this software in a 
* product, an acknowledgment in the product documentation would be 
* appreciated but is not required.
*
* 2. Altered source versions must be plainly marked as such, and must not be
* misrepresented as being the original software.
*
* 3. This notice may not be removed or altered from any source distribution.
*/

#include "x86_64SystemVDefault.h"

#include <algorithm>

namespace
{
	bool IsSseType(DataType_t type)
	{
		return type == DATA_TYPE_FLOAT || type == DATA_TYPE_DOUBLE;
	}

	bool IsScalarType(DataType_t type)
	{
		return type >= DATA_TYPE_BOOL && type <= DATA_TYPE_STRING;
	}

	bool IsSupportedValue(const DataTypeSized_t &type)
	{
		if (!IsScalarType(type.type) || type.size == 0 || type.size > 8)
			return false;
		if (type.type == DATA_TYPE_DOUBLE && type.size != 8)
			return false;
		if (type.type == DATA_TYPE_FLOAT && type.size != 4 && type.size != 8)
			return false;
		return true;
	}
}

x86_64SystemVDefault::x86_64SystemVDefault(
	std::vector<DataTypeSized_t> &vecArgTypes,
	DataTypeSized_t returnType,
	int iAlignment)
	: ICallingConvention(vecArgTypes, returnType, iAlignment),
	  m_stackArgs(0)
{
	if (m_returnType.custom_register != None)
	{
		SetError("Custom return registers are not supported on Linux x64.");
		return;
	}
	if (m_returnType.type != DATA_TYPE_VOID && !IsSupportedValue(m_returnType))
	{
		SetError("The return type is not supported by the Linux x64 calling convention.");
		return;
	}

	for (const auto &arg : m_vecArgTypes)
	{
		if (arg.custom_register != None)
		{
			SetError("Custom argument registers are not supported on Linux x64.");
			return;
		}
		if (!IsSupportedValue(arg))
		{
			SetError("An argument type is not supported by the Linux x64 calling convention.");
			return;
		}
	}

	const Register_t integerRegisters[] = {RDI, RSI, RDX, RCX, R8, R9};
	const Register_t sseRegisters[] = {XMM0, XMM1, XMM2, XMM3, XMM4, XMM5, XMM6, XMM7};
	std::size_t integerIndex = 0;
	std::size_t sseIndex = 0;

	for (auto &arg : m_vecArgTypes)
	{
		if (IsSseType(arg.type))
		{
			if (sseIndex < sizeof(sseRegisters) / sizeof(sseRegisters[0]))
				arg.custom_register = sseRegisters[sseIndex++];
			else
				m_stackArgs++;
		}
		else
		{
			if (integerIndex < sizeof(integerRegisters) / sizeof(integerRegisters[0]))
				arg.custom_register = integerRegisters[integerIndex++];
			else
				m_stackArgs++;
		}
	}
}

std::vector<Register_t> x86_64SystemVDefault::GetRegisters()
{
	std::vector<Register_t> registers;
	auto add = [&registers](Register_t reg) {
		if (std::find(registers.begin(), registers.end(), reg) == registers.end())
			registers.push_back(reg);
	};

	add(RSP);
	add(RAX);
	if (m_returnType.type != DATA_TYPE_VOID)
		add(IsSseType(m_returnType.type) ? XMM0 : RAX);
	for (const auto &arg : m_vecArgTypes)
	{
		if (arg.custom_register != None)
			add(arg.custom_register);
	}
	return registers;
}

int x86_64SystemVDefault::GetPopSize()
{
	return 0;
}

int x86_64SystemVDefault::GetArgStackSize()
{
	return static_cast<int>(m_stackArgs * 8);
}

void **x86_64SystemVDefault::GetStackArgumentPtr(CRegisters *registers)
{
	if (!registers || !registers->m_rsp)
		return nullptr;
	return reinterpret_cast<void **>(
		registers->m_rsp->GetValue<std::uintptr_t>() + sizeof(void *));
}

int x86_64SystemVDefault::GetArgRegisterSize()
{
	int size = 0;
	for (const auto &arg : m_vecArgTypes)
	{
		if (arg.custom_register != None)
			size += 8;
	}
	return size;
}

void *x86_64SystemVDefault::GetArgumentPtr(unsigned int index, CRegisters *registers)
{
	if (!registers || index >= m_vecArgTypes.size())
		return nullptr;

	if (!m_callArgumentContexts.empty())
	{
		CallArgumentContext &context = m_callArgumentContexts.back();
		if (context.aliasedArgument == index && context.aliasedValue)
			return context.aliasedValue.get();
	}

	return GetLiveArgumentPtr(index, registers);
}

void *x86_64SystemVDefault::GetLiveArgumentPtr(
	unsigned int index,
	CRegisters *registers)
{
	const auto &arg = m_vecArgTypes[index];
	if (arg.custom_register != None)
	{
		CRegister *reg = registers->GetRegister(arg.custom_register);
		return reg ? reg->m_pAddress : nullptr;
	}

	if (!registers->m_rsp)
		return nullptr;
	std::size_t stackIndex = 0;
	for (unsigned int i = 0; i < index; i++)
	{
		if (m_vecArgTypes[i].custom_register == None)
			stackIndex++;
	}
	return reinterpret_cast<void *>(
		registers->m_rsp->GetValue<std::uintptr_t>() + sizeof(void *) + stackIndex * 8);
}

void x86_64SystemVDefault::ArgumentPtrChanged(
	unsigned int index,
	CRegisters *registers,
	void *argumentPtr)
{
	(void)index;
	(void)registers;
	(void)argumentPtr;
}

void *x86_64SystemVDefault::GetReturnPtr(CRegisters *registers)
{
	if (!registers || m_returnType.type == DATA_TYPE_VOID)
		return nullptr;
	CRegister *reg = IsSseType(m_returnType.type) ? registers->m_xmm0 : registers->m_rax;
	return reg ? reg->m_pAddress : nullptr;
}

void x86_64SystemVDefault::ReturnPtrChanged(
	CRegisters *registers,
	void *returnPtr)
{
	(void)registers;
	(void)returnPtr;
}

void x86_64SystemVDefault::SaveReturnValue(CRegisters *registers)
{
	void *value = GetReturnPtr(registers);
	if (!value)
		return;
	std::unique_ptr<uint8_t[]> saved = std::make_unique<uint8_t[]>(8);
	memcpy(saved.get(), value, 8);
	m_pSavedReturnBuffers.push_back(std::move(saved));
}

void x86_64SystemVDefault::RestoreReturnValue(CRegisters *registers)
{
	if (m_pSavedReturnBuffers.empty())
		return;
	void *value = GetReturnPtr(registers);
	if (!value)
		return;
	memcpy(value, m_pSavedReturnBuffers.back().get(), 8);
	m_pSavedReturnBuffers.pop_back();
}

void x86_64SystemVDefault::SaveCallArguments(CRegisters *registers)
{
	if (!registers || !registers->m_rsp || !registers->m_rax)
		return;

	std::unique_ptr<uint8_t[]> saved =
		std::make_unique<uint8_t[]>(m_vecArgTypes.size() * 8);
	for (std::size_t i = 0; i < m_vecArgTypes.size(); i++)
		memcpy(saved.get() + i * 8, GetArgumentPtr(static_cast<unsigned int>(i), registers), 8);
	m_pSavedCallArguments.push_back(std::move(saved));
	m_savedStackPointers.push_back(registers->m_rsp->GetValue<std::uintptr_t>());
	m_savedArgumentRax.push_back(registers->m_rax->GetValue<std::uint64_t>());
}

void x86_64SystemVDefault::RestoreCallArguments(CRegisters *registers)
{
	if (!registers ||
		!registers->m_rsp ||
		!registers->m_rax ||
		m_pSavedCallArguments.empty() ||
		m_savedStackPointers.empty() ||
		m_savedArgumentRax.empty())
		return;
	registers->m_rsp->SetValue<std::uintptr_t>(m_savedStackPointers.back());
	for (std::size_t i = 0; i < m_vecArgTypes.size(); i++)
		memcpy(
			GetArgumentPtr(static_cast<unsigned int>(i), registers),
			m_pSavedCallArguments.back().get() + i * 8,
			8);
	registers->m_rax->SetValue<std::uint64_t>(m_savedArgumentRax.back());
	m_pSavedCallArguments.pop_back();
	m_savedStackPointers.pop_back();
	m_savedArgumentRax.pop_back();
}

void x86_64SystemVDefault::BeginCallContext(CRegisters *registers)
{
	m_callArgumentContexts.emplace_back();
	if (!registers || !IsSseType(m_returnType.type))
		return;

	CallArgumentContext &context = m_callArgumentContexts.back();
	for (std::size_t i = 0; i < m_vecArgTypes.size(); i++)
	{
		if (m_vecArgTypes[i].custom_register != XMM0)
			continue;
		void *argument = GetLiveArgumentPtr(
			static_cast<unsigned int>(i),
			registers);
		if (!argument)
			return;
		context.aliasedArgument = i;
		context.aliasedValue = std::make_unique<uint8_t[]>(8);
		memcpy(context.aliasedValue.get(), argument, 8);
		return;
	}
}

void x86_64SystemVDefault::ApplyCallArguments(CRegisters *registers)
{
	if (!registers || m_callArgumentContexts.empty())
		return;

	CallArgumentContext &context = m_callArgumentContexts.back();
	if (!context.aliasedValue)
		return;
	void *argument = GetLiveArgumentPtr(
		static_cast<unsigned int>(context.aliasedArgument),
		registers);
	if (argument)
		memcpy(argument, context.aliasedValue.get(), 8);
}

void x86_64SystemVDefault::EndCallContext()
{
	if (!m_callArgumentContexts.empty())
		m_callArgumentContexts.pop_back();
}
