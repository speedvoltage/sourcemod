#include "../vhook.h"

#include <array>
#include <cstdint>
#include <cstdio>
#include <memory>
#include <thread>
#include <vector>

using namespace SourceHook;
using namespace SourceHook::Asm;

std::thread::id g_MainThreadId;

#if !defined(SH_X64_JIT_WRITER_REQUIRES_ALLOCATOR)
SourceHook::CPageAlloc SourceHook::Asm::GenBuffer::ms_Allocator;
#endif

enum class ParamClass
{
	Basic,
	Float32,
	Float64
};

static void AddParam(
	HookSetup *setup,
	ParamClass paramClass,
	unsigned int flags = PASSFLAG_BYVAL)
{
	ParamInfo param = {};
	param.flags = flags;
	param.custom_register = None;
	if (paramClass == ParamClass::Basic)
	{
		param.type = HookParamType_ObjectPtr;
		param.size = sizeof(void *);
		param.pass_type = SourceHook::PassInfo::PassType_Basic;
	}
	else
	{
		param.type = HookParamType_Float;
		param.size =
			paramClass == ParamClass::Float32
				? sizeof(float)
				: sizeof(double);
		param.pass_type = SourceHook::PassInfo::PassType_Float;
	}
	setup->params.push_back(param);
}

struct CaptureContext
{
	uint64_t entryAlignment;
	const uint64_t* expected;
	size_t count;
	bool matched;
};

extern "C" uint64_t CaptureThunkImpl(CaptureContext* context, const uint64_t* slots)
{
	context->matched = true;
	for (size_t i = 0; i < context->count; i++)
	{
		if (slots[i] != context->expected[i])
		{
			context->matched = false;
			std::fprintf(
				stderr,
				"slot %zu: expected 0x%llx, got 0x%llx\n",
				i,
				static_cast<unsigned long long>(context->expected[i]),
				static_cast<unsigned long long>(slots[i]));
		}
	}
	return 0x9abcdeff12345678ULL;
}

extern "C" __attribute__((naked)) uint64_t CaptureThunk()
{
	asm volatile(
		"mov %rsp, %rax\n"
		"and $15, %eax\n"
		"mov %rax, (%rdi)\n"
		"jmp CaptureThunkImpl\n");
}

extern "C" float CaptureFloatThunk(CaptureContext* context, const uint64_t* slots)
{
	context->matched = true;
	for (size_t i = 0; i < context->count; i++)
		context->matched = context->matched && slots[i] == context->expected[i];
	return 123.25f;
}

static uint64_t FloatBits(float value)
{
	union
	{
		float value;
		uint32_t bits;
	} converted = { value };
	return converted.bits;
}

static uint64_t DoubleBits(double value)
{
	union
	{
		double value;
		uint64_t bits;
	} converted = { value };
	return converted.bits;
}

int main()
{
	g_MainThreadId = std::this_thread::get_id();
	CPageAlloc allocator(16);
	const std::vector<ParamClass> mixedParams = {
		ParamClass::Basic,
		ParamClass::Float32,
		ParamClass::Basic,
		ParamClass::Float64,
		ParamClass::Basic,
		ParamClass::Float32,
		ParamClass::Basic,
		ParamClass::Float64,
		ParamClass::Basic,
		ParamClass::Float32,
		ParamClass::Basic,
		ParamClass::Float64,
		ParamClass::Float32,
		ParamClass::Float64,
		ParamClass::Float32,
		ParamClass::Basic,
		ParamClass::Float64
	};
	HookSetup mixedSetup(
		ReturnType_Int,
		PASSFLAG_BYVAL,
		HookType_Raw,
		ThisPointer_Ignore,
		0,
		nullptr);
	for (ParamClass paramClass : mixedParams)
		AddParam(&mixedSetup, paramClass);
	const std::array<uint64_t, 17> expected = {
		0x101,
		FloatBits(1.25f),
		0x202,
		DoubleBits(2.5),
		0x303,
		FloatBits(3.75f),
		0x404,
		DoubleBits(4.5),
		0x505,
		FloatBits(5.25f),
		0x606,
		DoubleBits(6.5),
		FloatBits(7.25f),
		DoubleBits(8.5),
		FloatBits(9.25f),
		0x707,
		DoubleBits(10.5)
	};
	CaptureContext context = { 0, expected.data(), expected.size(), false };
	std::unique_ptr<x64JitWriter> mixedThunk(
		GenerateSysVVHookThunk(
			&mixedSetup,
			&allocator,
			reinterpret_cast<uint64_t>(CaptureThunk),
			reinterpret_cast<uint64_t>(CaptureFloatThunk)));
	using MixedFunction = uint64_t (*)(
		CaptureContext*,
		uint64_t,
		float,
		uint64_t,
		double,
		uint64_t,
		float,
		uint64_t,
		double,
		uint64_t,
		float,
		uint64_t,
		double,
		float,
		double,
		float,
		uint64_t,
		double);
	auto mixedFunction = reinterpret_cast<MixedFunction>(mixedThunk->GetData());
	const uint64_t mixedReturn = mixedFunction(
		&context,
		0x101,
		1.25f,
		0x202,
		2.5,
		0x303,
		3.75f,
		0x404,
		4.5,
		0x505,
		5.25f,
		0x606,
		6.5,
		7.25f,
		8.5,
		9.25f,
		0x707,
		10.5);
	if (!context.matched ||
		context.entryAlignment != 8 ||
		mixedReturn != 0x9abcdeff12345678ULL)
	{
		std::fprintf(
			stderr,
			"mixed SysV virtual thunk test failed: alignment=%llu return=0x%llx\n",
			static_cast<unsigned long long>(context.entryAlignment),
			static_cast<unsigned long long>(mixedReturn));
		return 1;
	}

	const std::array<uint64_t, 1> floatExpected = {
		FloatBits(11.75f)
	};
	CaptureContext floatContext = {
		0,
		floatExpected.data(),
		floatExpected.size(),
		false
	};
	HookSetup floatSetup(
		ReturnType_Float,
		PASSFLAG_BYVAL,
		HookType_Raw,
		ThisPointer_Ignore,
		0,
		nullptr);
	AddParam(&floatSetup, ParamClass::Float32);
	std::unique_ptr<x64JitWriter> floatThunk(
		GenerateSysVVHookThunk(
			&floatSetup,
			&allocator,
			reinterpret_cast<uint64_t>(CaptureThunk),
			reinterpret_cast<uint64_t>(CaptureFloatThunk)));
	using FloatFunction = float (*)(CaptureContext*, float);
	auto floatFunction = reinterpret_cast<FloatFunction>(floatThunk->GetData());
	const float floatReturn = floatFunction(&floatContext, 11.75f);
	if (!floatContext.matched || floatReturn != 123.25f)
	{
		std::fprintf(stderr, "float SysV virtual thunk test failed\n");
		return 1;
	}

	HookSetup byReferenceSetup(
		ReturnType_Int,
		PASSFLAG_BYVAL,
		HookType_Raw,
		ThisPointer_Ignore,
		0,
		nullptr);
	AddParam(&byReferenceSetup, ParamClass::Basic, PASSFLAG_BYREF);
	if (GenerateSysVVHookThunk(
			&byReferenceSetup,
			&allocator,
			reinterpret_cast<uint64_t>(CaptureThunk),
			reinterpret_cast<uint64_t>(CaptureFloatThunk)) != nullptr)
	{
		std::fprintf(stderr, "by-reference parameter rejection test failed\n");
		return 1;
	}

	HookSetup rejectedSetup(
		ReturnType_Vector,
		PASSFLAG_BYVAL,
		HookType_Raw,
		ThisPointer_Ignore,
		0,
		nullptr);
	if (GenerateSysVVHookThunk(
			&rejectedSetup,
			&allocator,
			reinterpret_cast<uint64_t>(CaptureThunk),
			reinterpret_cast<uint64_t>(CaptureFloatThunk)) != nullptr)
	{
		std::fprintf(stderr, "aggregate rejection test failed\n");
		return 1;
	}

	std::puts("DHooks SysV virtual thunk passed");
	return 0;
}
