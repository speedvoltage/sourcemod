#include "../DynamicHooks/conventions/x86_64SystemVDefault.h"

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <vector>

namespace
{
	int failures;

	void Expect(bool condition, const char *name)
	{
		std::printf("%s %s\n", condition ? "ok" : "not ok", name);
		if (!condition)
			failures++;
	}

	DataTypeSized_t Type(
		DataType_t type,
		std::size_t size = 0,
		Register_t customRegister = None)
	{
		DataTypeSized_t value;
		value.type = type;
		value.size = size;
		value.custom_register = customRegister;
		return value;
	}

	bool HasRegister(const std::vector<Register_t> &registers, Register_t reg)
	{
		return std::find(registers.begin(), registers.end(), reg) != registers.end();
	}

	x86_64SystemVDefault IntegerConvention(std::size_t count)
	{
		std::vector<DataTypeSized_t> args(count, Type(DATA_TYPE_ULONG_LONG, 8));
		return x86_64SystemVDefault(args, Type(DATA_TYPE_ULONG_LONG, 8));
	}

	void TestIntegerAndThisLayout()
	{
		std::vector<DataTypeSized_t> args;
		args.push_back(Type(DATA_TYPE_POINTER, 8));
		for (int i = 0; i < 6; i++)
			args.push_back(Type(DATA_TYPE_INT, 4));
		x86_64SystemVDefault convention(args, Type(DATA_TYPE_VOID));
		const Register_t expected[] = {RDI, RSI, RDX, RCX, R8, R9, None};

		bool layout = convention.IsValid();
		for (std::size_t i = 0; i < convention.m_vecArgTypes.size(); i++)
			layout = layout && convention.m_vecArgTypes[i].custom_register == expected[i];
		Expect(layout, "implicit this consumes the first GPR");
		Expect(convention.GetArgStackSize() == 8, "seventh integer-class value spills");
		Expect(convention.GetArgRegisterSize() == 48, "six integer registers use six slots");
	}

	void TestSseLayout()
	{
		std::vector<DataTypeSized_t> args(9, Type(DATA_TYPE_DOUBLE, 8));
		x86_64SystemVDefault convention(args, Type(DATA_TYPE_DOUBLE, 8));
		const Register_t expected[] = {
			XMM0, XMM1, XMM2, XMM3, XMM4, XMM5, XMM6, XMM7, None
		};

		bool layout = convention.IsValid();
		for (std::size_t i = 0; i < convention.m_vecArgTypes.size(); i++)
			layout = layout && convention.m_vecArgTypes[i].custom_register == expected[i];
		Expect(layout, "SSE values use XMM0 through XMM7");
		Expect(convention.GetArgStackSize() == 8, "ninth SSE value spills");
	}

	void TestIndependentStreams()
	{
		std::vector<DataTypeSized_t> args = {
			Type(DATA_TYPE_POINTER, 8),
			Type(DATA_TYPE_INT, 4),
			Type(DATA_TYPE_FLOAT, 4),
			Type(DATA_TYPE_INT, 4),
			Type(DATA_TYPE_DOUBLE, 8),
			Type(DATA_TYPE_INT, 4),
			Type(DATA_TYPE_FLOAT, 4)
		};
		x86_64SystemVDefault convention(args, Type(DATA_TYPE_INT, 4));
		const Register_t expected[] = {RDI, RSI, XMM0, RDX, XMM1, RCX, XMM2};

		bool layout = convention.IsValid();
		for (std::size_t i = 0; i < convention.m_vecArgTypes.size(); i++)
			layout = layout && convention.m_vecArgTypes[i].custom_register == expected[i];
		Expect(layout, "integer and SSE register streams are independent");
	}

	void TestStackOrderAndPointers()
	{
		std::vector<DataTypeSized_t> args;
		for (int i = 0; i < 6; i++)
			args.push_back(Type(DATA_TYPE_ULONG_LONG, 8));
		for (int i = 0; i < 8; i++)
			args.push_back(Type(DATA_TYPE_DOUBLE, 8));
		args.push_back(Type(DATA_TYPE_INT, 4));
		args.push_back(Type(DATA_TYPE_DOUBLE, 8));
		args.push_back(Type(DATA_TYPE_POINTER, 8));

		x86_64SystemVDefault convention(args, Type(DATA_TYPE_POINTER, 8));
		CRegisters registers(convention.GetRegisters());
		std::uintptr_t stack[] = {0, 101, 202, 303};
		registers.m_rsp->SetValue<std::uintptr_t>(
			reinterpret_cast<std::uintptr_t>(stack));

		bool order =
			convention.GetArgStackSize() == 24 &&
			convention.GetStackArgumentPtr(&registers) == reinterpret_cast<void **>(&stack[1]) &&
			convention.GetArgumentPtr(14, &registers) == &stack[1] &&
			convention.GetArgumentPtr(15, &registers) == &stack[2] &&
			convention.GetArgumentPtr(16, &registers) == &stack[3];
		Expect(order, "mixed spills retain source order");
		Expect(
			convention.GetArgumentPtr(0, &registers) == registers.m_rdi->m_pAddress &&
			convention.GetArgumentPtr(6, &registers) == registers.m_xmm0->m_pAddress,
			"register argument pointers select the assigned snapshots");
	}

	void TestReturnRegisters()
	{
		std::vector<DataTypeSized_t> integerArgs;
		x86_64SystemVDefault integerConvention(
			integerArgs,
			Type(DATA_TYPE_INT, 4));
		CRegisters integerRegisters(integerConvention.GetRegisters());

		std::vector<DataTypeSized_t> floatArgs;
		x86_64SystemVDefault floatConvention(
			floatArgs,
			Type(DATA_TYPE_FLOAT, 4));
		CRegisters floatRegisters(floatConvention.GetRegisters());

		std::vector<DataTypeSized_t> voidArgs;
		x86_64SystemVDefault voidConvention(
			voidArgs,
			Type(DATA_TYPE_VOID));
		CRegisters voidRegisters(voidConvention.GetRegisters());

		Expect(
			integerConvention.GetReturnPtr(&integerRegisters) ==
				integerRegisters.m_rax->m_pAddress,
			"integer return uses RAX");
		Expect(
			floatConvention.GetReturnPtr(&floatRegisters) ==
				floatRegisters.m_xmm0->m_pAddress,
			"floating return uses XMM0");
		Expect(
			voidConvention.GetReturnPtr(&voidRegisters) == nullptr,
			"void return has no value register");
		Expect(
			HasRegister(floatConvention.GetRegisters(), XMM0) &&
			!HasRegister(floatConvention.GetRegisters(), RAX),
			"return register set matches the return class");
	}

	void TestNestedSnapshots()
	{
		x86_64SystemVDefault convention = IntegerConvention(7);
		CRegisters registers(convention.GetRegisters());
		std::uintptr_t stack[] = {0, 17};
		registers.m_rsp->SetValue<std::uintptr_t>(
			reinterpret_cast<std::uintptr_t>(stack));

		for (unsigned int i = 0; i < 7; i++)
			*reinterpret_cast<std::uint64_t *>(
				convention.GetArgumentPtr(i, &registers)) = i + 1;
		*reinterpret_cast<std::uint64_t *>(
			convention.GetReturnPtr(&registers)) = 41;

		convention.SaveCallArguments(&registers);
		convention.SaveReturnValue(&registers);
		for (unsigned int i = 0; i < 7; i++)
			*reinterpret_cast<std::uint64_t *>(
				convention.GetArgumentPtr(i, &registers)) = i + 101;
		*reinterpret_cast<std::uint64_t *>(
			convention.GetReturnPtr(&registers)) = 141;

		convention.SaveCallArguments(&registers);
		convention.SaveReturnValue(&registers);
		for (unsigned int i = 0; i < 7; i++)
			*reinterpret_cast<std::uint64_t *>(
				convention.GetArgumentPtr(i, &registers)) = i + 201;
		*reinterpret_cast<std::uint64_t *>(
			convention.GetReturnPtr(&registers)) = 241;

		convention.RestoreCallArguments(&registers);
		convention.RestoreReturnValue(&registers);
		bool inner = true;
		for (unsigned int i = 0; i < 7; i++)
			inner = inner &&
				*reinterpret_cast<std::uint64_t *>(
					convention.GetArgumentPtr(i, &registers)) == i + 101;
		inner = inner &&
			*reinterpret_cast<std::uint64_t *>(
				convention.GetReturnPtr(&registers)) == 141;

		convention.RestoreCallArguments(&registers);
		convention.RestoreReturnValue(&registers);
		bool outer = true;
		for (unsigned int i = 0; i < 7; i++)
			outer = outer &&
				*reinterpret_cast<std::uint64_t *>(
					convention.GetArgumentPtr(i, &registers)) == i + 1;
		outer = outer &&
			*reinterpret_cast<std::uint64_t *>(
				convention.GetReturnPtr(&registers)) == 41;

		Expect(inner && outer, "argument and return snapshots restore in LIFO order");
	}

	void TestRejections()
	{
		std::vector<DataTypeSized_t> objectArgs = {
			Type(DATA_TYPE_OBJECT, 12)
		};
		x86_64SystemVDefault objectArg(
			objectArgs,
			Type(DATA_TYPE_VOID));

		std::vector<DataTypeSized_t> customArgs = {
			Type(DATA_TYPE_INT, 4, RDI)
		};
		x86_64SystemVDefault customArg(
			customArgs,
			Type(DATA_TYPE_VOID));

		std::vector<DataTypeSized_t> voidArgs = {
			Type(DATA_TYPE_VOID)
		};
		x86_64SystemVDefault voidArg(
			voidArgs,
			Type(DATA_TYPE_VOID));

		std::vector<DataTypeSized_t> wideArgs = {
			Type(DATA_TYPE_INT, 16)
		};
		x86_64SystemVDefault wideArg(
			wideArgs,
			Type(DATA_TYPE_VOID));

		std::vector<DataTypeSized_t> noArgs;
		x86_64SystemVDefault objectReturn(
			noArgs,
			Type(DATA_TYPE_OBJECT, 12));

		std::vector<DataTypeSized_t> noCustomArgs;
		x86_64SystemVDefault customReturn(
			noCustomArgs,
			Type(DATA_TYPE_INT, 4, RAX));

		Expect(
			!objectArg.IsValid() &&
			!customArg.IsValid() &&
			!voidArg.IsValid() &&
			!wideArg.IsValid() &&
			!objectReturn.IsValid() &&
			!customReturn.IsValid(),
			"unsupported layouts fail closed");
		Expect(
			!objectArg.GetError().empty() &&
			!customReturn.GetError().empty(),
			"rejections retain a diagnostic");
	}
}

int main()
{
	TestIntegerAndThisLayout();
	TestSseLayout();
	TestIndependentStreams();
	TestStackOrderAndPointers();
	TestReturnRegisters();
	TestNestedSnapshots();
	TestRejections();

	if (failures != 0)
	{
		std::printf("DHooks SysV convention failed: %d\n", failures);
		return 1;
	}

	std::printf("DHooks SysV convention passed\n");
	return 0;
}
