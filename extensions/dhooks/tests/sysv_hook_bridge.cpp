#include "../DynamicHooks/manager.h"
#include "../DynamicHooks/conventions/x86_64SystemVDefault.h"
#include <smsdk_ext.h>

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <thread>
#include <utility>
#include <vector>

IExtension *myself;
ISourceMod *g_pSM;
ISourceMod *smutils;
std::thread::id g_MainThreadId;

extern "C" std::uint64_t dhooks_hook_integer_target(std::uint64_t value);
extern "C" double dhooks_hook_double_target(double value);
extern "C" double dhooks_hook_override_target(double value);
extern "C" double dhooks_hook_variadic_target(int count, ...);
extern "C" std::uint64_t dhooks_hook_mixed_target(
	std::uint64_t,
	double,
	std::uint64_t,
	double,
	std::uint64_t,
	double,
	std::uint64_t,
	double,
	std::uint64_t,
	double,
	std::uint64_t,
	double,
	std::uint64_t,
	double,
	double,
	double);

extern "C" {
std::uint32_t dhooks_hook_handler_alignment_mask;
}

namespace
{
	int failures;
	int preCalls;
	int postCalls;
	bool postSawOverride;
	bool postSawDoubleArgument;
	bool postSawOverrideArgument;
	bool runningRecursiveVariadic;
	bool ranRecursiveVariadic;
	bool recursiveVariadicClobberedRax;
	bool recursiveVariadicRestoredRax;
	double recursiveVariadicResult;
	CHook *doubleHook;
	CHook *overrideHook;
	CHook *variadicHook;

	void Expect(bool condition, const char *name)
	{
		std::printf("%s %s\n", condition ? "ok" : "not ok", name);
		if (!condition)
			failures++;
	}

	bool Close(double actual, double expected)
	{
		return std::fabs(actual - expected) <= 0.000000001;
	}

	DataTypeSized_t Type(DataType_t type, std::size_t size)
	{
		DataTypeSized_t value;
		value.type = type;
		value.size = size;
		value.custom_register = None;
		return value;
	}

	CHook *Install(
		CHookManager &manager,
		void *target,
		DataTypeSized_t argument,
		DataTypeSized_t result);

	CHook *Install(
		CHookManager &manager,
		void *target,
		std::vector<DataTypeSized_t> arguments,
		DataTypeSized_t result);
}

extern "C" ReturnAction_t
dhooks_hook_handler_body(HookType_t type, CHook *hook)
{
	if (type == HOOKTYPE_PRE)
	{
		preCalls++;
		if (hook == variadicHook && !runningRecursiveVariadic)
		{
			const std::uint64_t savedRax =
				hook->m_pRegisters->m_rax->GetValue<std::uint64_t>();
			hook->m_pCallingConvention->SaveCallArguments(hook->m_pRegisters);
			runningRecursiveVariadic = true;
			recursiveVariadicResult = dhooks_hook_variadic_target(0);
			runningRecursiveVariadic = false;
			recursiveVariadicClobberedRax =
				hook->m_pRegisters->m_rax->GetValue<std::uint64_t>() !=
				savedRax;
			hook->m_pCallingConvention->RestoreCallArguments(hook->m_pRegisters);
			recursiveVariadicRestoredRax =
				hook->m_pRegisters->m_rax->GetValue<std::uint64_t>() ==
				savedRax;
			ranRecursiveVariadic = true;
		}
		if (hook == overrideHook)
		{
			hook->SetReturnValue<double>(91.25);
			return ReturnAction_Override;
		}
	}
	else
	{
		postCalls++;
		if (hook == doubleHook)
		{
			postSawDoubleArgument =
				Close(hook->GetArgument<double>(0), 13.5) &&
				Close(hook->GetReturnValue<double>(), 27.625);
		}
		if (hook == overrideHook)
		{
			postSawOverride = Close(hook->GetReturnValue<double>(), 91.25);
			postSawOverrideArgument =
				Close(hook->GetArgument<double>(0), 6.5);
		}
	}
	return ReturnAction_Ignored;
}

extern "C" __attribute__((naked)) ReturnAction_t
dhooks_hook_handler(HookType_t, CHook *)
{
	asm volatile(
		"movq %rsp, %rcx\n"
		"andl $15, %ecx\n"
		"movl $1, %eax\n"
		"shll %cl, %eax\n"
		"orl %eax, dhooks_hook_handler_alignment_mask(%rip)\n"
		"jmp dhooks_hook_handler_body\n");
}

namespace
{
	CHook *Install(
		CHookManager &manager,
		void *target,
		DataTypeSized_t argument,
		DataTypeSized_t result)
	{
		return Install(
			manager,
			target,
			std::vector<DataTypeSized_t>{argument},
			result);
	}

	CHook *Install(
		CHookManager &manager,
		void *target,
		std::vector<DataTypeSized_t> arguments,
		DataTypeSized_t result)
	{
		auto *convention = new x86_64SystemVDefault(arguments, result);
		CHook *hook = manager.HookFunction(target, convention);
		if (!hook)
			return nullptr;
		hook->AddCallback(
			HOOKTYPE_PRE,
			reinterpret_cast<HookHandlerFn *>(&dhooks_hook_handler));
		hook->AddCallback(
			HOOKTYPE_POST,
			reinterpret_cast<HookHandlerFn *>(&dhooks_hook_handler));
		return hook;
	}
}

int main()
{
	g_MainThreadId = std::this_thread::get_id();
	CHookManager manager;
	CHook *integerHook = Install(
		manager,
		reinterpret_cast<void *>(&dhooks_hook_integer_target),
		Type(DATA_TYPE_ULONG_LONG, 8),
		Type(DATA_TYPE_ULONG_LONG, 8));
	doubleHook = Install(
		manager,
		reinterpret_cast<void *>(&dhooks_hook_double_target),
		Type(DATA_TYPE_DOUBLE, 8),
		Type(DATA_TYPE_DOUBLE, 8));
	overrideHook = Install(
		manager,
		reinterpret_cast<void *>(&dhooks_hook_override_target),
		Type(DATA_TYPE_DOUBLE, 8),
		Type(DATA_TYPE_DOUBLE, 8));
	std::vector<DataTypeSized_t> mixedArguments = {
		Type(DATA_TYPE_ULONG_LONG, 8),
		Type(DATA_TYPE_DOUBLE, 8),
		Type(DATA_TYPE_ULONG_LONG, 8),
		Type(DATA_TYPE_DOUBLE, 8),
		Type(DATA_TYPE_ULONG_LONG, 8),
		Type(DATA_TYPE_DOUBLE, 8),
		Type(DATA_TYPE_ULONG_LONG, 8),
		Type(DATA_TYPE_DOUBLE, 8),
		Type(DATA_TYPE_ULONG_LONG, 8),
		Type(DATA_TYPE_DOUBLE, 8),
		Type(DATA_TYPE_ULONG_LONG, 8),
		Type(DATA_TYPE_DOUBLE, 8),
		Type(DATA_TYPE_ULONG_LONG, 8),
		Type(DATA_TYPE_DOUBLE, 8),
		Type(DATA_TYPE_DOUBLE, 8),
		Type(DATA_TYPE_DOUBLE, 8),
	};
	CHook *mixedHook = Install(
		manager,
		reinterpret_cast<void *>(&dhooks_hook_mixed_target),
		std::move(mixedArguments),
		Type(DATA_TYPE_ULONG_LONG, 8));
	std::vector<DataTypeSized_t> variadicArguments = {
		Type(DATA_TYPE_INT, 4),
		Type(DATA_TYPE_DOUBLE, 8),
		Type(DATA_TYPE_DOUBLE, 8),
	};
	variadicHook = Install(
		manager,
		reinterpret_cast<void *>(&dhooks_hook_variadic_target),
		std::move(variadicArguments),
		Type(DATA_TYPE_DOUBLE, 8));

	Expect(integerHook && integerHook->IsInstalled(), "integer hook installed");
	Expect(doubleHook && doubleHook->IsInstalled(), "double hook installed");
	Expect(overrideHook && overrideHook->IsInstalled(), "override hook installed");
	Expect(mixedHook && mixedHook->IsInstalled(), "mixed hook installed");
	Expect(variadicHook && variadicHook->IsInstalled(), "variadic hook installed");

	decltype(&dhooks_hook_integer_target) volatile integerTarget =
		&dhooks_hook_integer_target;
	decltype(&dhooks_hook_double_target) volatile doubleTarget =
		&dhooks_hook_double_target;
	decltype(&dhooks_hook_override_target) volatile overrideTarget =
		&dhooks_hook_override_target;
	decltype(&dhooks_hook_mixed_target) volatile mixedTarget =
		&dhooks_hook_mixed_target;
	decltype(&dhooks_hook_variadic_target) volatile variadicTarget =
		&dhooks_hook_variadic_target;

	Expect(
		integerTarget(0x12345678ULL) == 0x5b05b05bULL,
		"integer return survives the post bridge");
	Expect(
		Close(doubleTarget(13.5), 27.625),
		"aliased XMM0 argument and return survive post restoration");
	Expect(
		postSawDoubleArgument,
		"post handler sees the original aliased XMM0 argument");
	Expect(
		Close(overrideTarget(6.5), 91.25),
		"pre override survives argument restoration");
	Expect(postSawOverride, "post handler observes the pre override");
	Expect(
		postSawOverrideArgument,
		"post handler sees the original argument alongside an override");
	Expect(
		mixedTarget(
			1, 10.0,
			2, 11.0,
			3, 12.0,
			4, 13.0,
			5, 14.0,
			6, 15.0,
			7, 16.0,
			17.0,
			18.0) == 266,
		"mixed register and stack arguments survive the hook bridge");
	Expect(
		Close(variadicTarget(2, 3.5, 4.25), 7.75),
		"recursive variadic hook retains the outer AL register count");
	Expect(
		ranRecursiveVariadic &&
			recursiveVariadicClobberedRax &&
			recursiveVariadicRestoredRax &&
			Close(recursiveVariadicResult, 0.0),
		"recursive variadic callback clobbers and restores RAX");
	Expect(
		dhooks_hook_handler_alignment_mask == (1u << 8),
		"hook handlers enter with SysV stack alignment");
	Expect(preCalls == 6 && postCalls == 6, "pre and post handlers ran");

	std::uint64_t workerResult = 0;
	std::uint64_t workerMixedResult = 0;
	std::thread worker([&]() {
		workerResult = integerTarget(0x87654321ULL);
		workerMixedResult = mixedTarget(
			1, 10.0,
			2, 11.0,
			3, 12.0,
			4, 13.0,
			5, 14.0,
			6, 15.0,
			7, 16.0,
			17.0,
			18.0);
	});
	worker.join();
	Expect(
		workerResult == 0x2a4fa4fa8ULL,
		"off-thread calls bypass the shared hook state");
	Expect(
		workerMixedResult == 266,
		"off-thread bypass preserves all scalar argument classes");
	Expect(preCalls == 6 && postCalls == 6, "off-thread calls skip hook handlers");

	manager.UnhookAllFunctions();
	Expect(manager.m_Hooks.empty(), "hooks uninstall cleanly");

	if (failures != 0)
	{
		std::printf("DHooks SysV hook bridge failed: %d\n", failures);
		return 1;
	}

	std::printf("DHooks SysV hook bridge passed\n");
	return 0;
}
