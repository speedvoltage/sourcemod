#include "../DynamicHooks/conventions/x86_64MicrosoftDefault.h"

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <vector>

namespace
{
	int failures;

	void Expect(bool condition, const char* name)
	{
		std::printf("%s %s\n", condition ? "ok" : "not ok", name);
		if (!condition)
			failures++;
	}

	DataTypeSized_t Type(DataType_t type, std::size_t size = 0)
	{
		DataTypeSized_t value;
		value.type = type;
		value.size = size;
		value.custom_register = None;
		return value;
	}

	double& DoubleAt(void* address)
	{
		return *reinterpret_cast<double*>(address);
	}

	bool Close(double left, double right)
	{
		return std::fabs(left - right) < 0.000001;
	}

	void TestAliasedPostValues()
	{
		std::vector<DataTypeSized_t> args = {
			Type(DATA_TYPE_DOUBLE, 8),
			Type(DATA_TYPE_INT, 4),
		};
		x86_64MicrosoftDefault convention(
			args,
			Type(DATA_TYPE_DOUBLE, 8));
		Expect(convention.IsValid(), "floating-return convention is valid");
		CRegisters registers(convention.GetRegisters());
		std::uintptr_t stack[5] = {};
		registers.m_rsp->SetValue<std::uintptr_t>(
			reinterpret_cast<std::uintptr_t>(stack));

		DoubleAt(registers.m_xmm0->m_pAddress) = 6.5;
		convention.BeginCallContext(&registers);
		Expect(
			convention.GetArgumentPtr(0, &registers) !=
				registers.m_xmm0->m_pAddress,
			"aliased XMM0 argument gets independent storage");

		DoubleAt(convention.GetArgumentPtr(0, &registers)) = 13.5;
		convention.ApplyCallArguments(&registers);
		Expect(
			Close(DoubleAt(registers.m_xmm0->m_pAddress), 13.5),
			"pre-hook XMM0 argument reaches the original call");

		convention.SaveCallArguments(&registers);
		DoubleAt(registers.m_xmm0->m_pAddress) = 27.625;
		convention.SaveReturnValue(&registers);
		convention.RestoreCallArguments(&registers);
		convention.RestoreReturnValue(&registers);

		Expect(
			Close(DoubleAt(convention.GetArgumentPtr(0, &registers)), 13.5),
			"post hook sees the call argument");
		Expect(
			Close(DoubleAt(convention.GetReturnPtr(&registers)), 27.625),
			"post hook sees the return value");

		convention.EndCallContext();
		Expect(
			convention.GetArgumentPtr(0, &registers) ==
				registers.m_xmm0->m_pAddress,
			"argument alias ends with the call context");
	}

	void TestNestedContexts()
	{
		std::vector<DataTypeSized_t> args = {
			Type(DATA_TYPE_DOUBLE, 8),
		};
		x86_64MicrosoftDefault convention(
			args,
			Type(DATA_TYPE_DOUBLE, 8));
		CRegisters registers(convention.GetRegisters());

		DoubleAt(registers.m_xmm0->m_pAddress) = 3.25;
		convention.BeginCallContext(&registers);
		DoubleAt(convention.GetArgumentPtr(0, &registers)) = 4.5;

		DoubleAt(registers.m_xmm0->m_pAddress) = 7.75;
		convention.BeginCallContext(&registers);
		Expect(
			Close(DoubleAt(convention.GetArgumentPtr(0, &registers)), 7.75),
			"nested call uses its own XMM0 argument");
		convention.EndCallContext();

		Expect(
			Close(DoubleAt(convention.GetArgumentPtr(0, &registers)), 4.5),
			"nested completion restores the outer argument context");
		convention.EndCallContext();
	}

	void TestOverridePostValues()
	{
		std::vector<DataTypeSized_t> args = {
			Type(DATA_TYPE_DOUBLE, 8),
		};
		x86_64MicrosoftDefault convention(
			args,
			Type(DATA_TYPE_DOUBLE, 8));
		CRegisters registers(convention.GetRegisters());

		DoubleAt(registers.m_xmm0->m_pAddress) = 2.5;
		convention.BeginCallContext(&registers);
		DoubleAt(convention.GetArgumentPtr(0, &registers)) = 8.25;
		DoubleAt(convention.GetReturnPtr(&registers)) = 19.75;
		convention.SaveReturnValue(&registers);
		convention.ApplyCallArguments(&registers);
		convention.SaveCallArguments(&registers);

		DoubleAt(registers.m_xmm0->m_pAddress) = 41.5;
		convention.RestoreReturnValue(&registers);
		convention.SaveReturnValue(&registers);
		convention.RestoreCallArguments(&registers);
		convention.RestoreReturnValue(&registers);

		Expect(
			Close(DoubleAt(convention.GetArgumentPtr(0, &registers)), 8.25),
			"post hook retains the argument after an override");
		Expect(
			Close(DoubleAt(convention.GetReturnPtr(&registers)), 19.75),
			"post hook retains the override return");
		convention.EndCallContext();
	}

	void TestNonAliasedArgument()
	{
		std::vector<DataTypeSized_t> args = {
			Type(DATA_TYPE_DOUBLE, 8),
		};
		x86_64MicrosoftDefault convention(
			args,
			Type(DATA_TYPE_INT, 4));
		Expect(convention.IsValid(), "integer-return convention is valid");
		CRegisters registers(convention.GetRegisters());

		convention.BeginCallContext(&registers);
		Expect(
			convention.GetArgumentPtr(0, &registers) ==
				registers.m_xmm0->m_pAddress,
			"non-aliased XMM0 argument keeps its live storage");
		convention.EndCallContext();
	}
}

int main()
{
	TestAliasedPostValues();
	TestNestedContexts();
	TestOverridePostValues();
	TestNonAliasedArgument();
	std::printf("%d failures\n", failures);
	return failures == 0 ? 0 : 1;
}
