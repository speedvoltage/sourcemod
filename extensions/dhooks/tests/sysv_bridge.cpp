#include <sh_asm_x86_64.h>

#include <cmath>
#include <cstdint>
#include <cstdio>

extern "C" {
std::uintptr_t dhooks_bridge_alignment;
std::uintptr_t dhooks_bridge_key_matches;
void *dhooks_bridge_target;
}

extern "C" __attribute__((naked)) std::uintptr_t
dhooks_bridge_probe_alignment()
{
	asm volatile(
		"movq %rsp, %rax\n"
		"andq $15, %rax\n"
		"ret\n");
}

extern "C" __attribute__((naked)) void *
dhooks_bridge_resolve_return(void *, void *)
{
	asm volatile(
		"movq %rsp, %rax\n"
		"andq $15, %rax\n"
		"movq %rax, dhooks_bridge_alignment(%rip)\n"
		"movq (%rsi), %rax\n"
		"cmpq dhooks_bridge_target(%rip), %rax\n"
		"sete %al\n"
		"movzbq %al, %rax\n"
		"movq %rax, dhooks_bridge_key_matches(%rip)\n"
		"movq dhooks_bridge_target(%rip), %rax\n"
		"pxor %xmm0, %xmm0\n"
		"ret\n");
}

extern "C" __attribute__((naked)) std::uint64_t
dhooks_bridge_run_integer(void *, std::uint64_t)
{
	asm volatile(
		"movq %rsi, %rax\n"
		"leaq 1f(%rip), %rdx\n"
		"movq %rdx, dhooks_bridge_target(%rip)\n"
		"subq $8, %rsp\n"
		"call *%rdi\n"
		"1:\n"
		"addq $8, %rsp\n"
		"ret\n");
}

extern "C" __attribute__((naked)) double
dhooks_bridge_run_double(void *, double)
{
	asm volatile(
		"leaq 1f(%rip), %rdx\n"
		"movq %rdx, dhooks_bridge_target(%rip)\n"
		"subq $8, %rsp\n"
		"call *%rdi\n"
		"1:\n"
		"addq $8, %rsp\n"
		"ret\n");
}

namespace
{
	int failures;

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
}

int main()
{
	using namespace SourceHook;
	using namespace SourceHook::Asm;

	CPageAlloc allocator(16);

	x64JitWriter alignedCall(&allocator);
	alignedCall.sub(rsp, 8);
	alignedCall.mov(
		rax,
		reinterpret_cast<std::uint64_t>(&dhooks_bridge_probe_alignment));
	alignedCall.call(rax);
	alignedCall.add(rsp, 8);
	alignedCall.retn();
	alignedCall.SetRE();

	auto callAlignment =
		reinterpret_cast<std::uintptr_t (*)()>(alignedCall.GetData());
	Expect(callAlignment() == 8, "helper call enters with SysV stack alignment");

	x64JitWriter postReturn(&allocator);
	postReturn.sub(rsp, 24);
	postReturn.mov(rsp(), rax);
	postReturn.movsd(rsp(8), xmm0);
	postReturn.lea(rsi, rsp(24));
	postReturn.mov(
		rax,
		reinterpret_cast<std::uint64_t>(&dhooks_bridge_resolve_return));
	postReturn.call(rax);
	postReturn.mov(r11, rax);
	postReturn.mov(rax, rsp());
	postReturn.movsd(xmm0, rsp(8));
	postReturn.add(rsp, 32);
	postReturn.jump(r11);
	postReturn.SetRE();

	void *postReturnAddress = postReturn.GetData();
	const std::uint64_t integerExpected = 0x123456789abcdef0ULL;
	Expect(
		dhooks_bridge_run_integer(postReturnAddress, integerExpected) ==
			integerExpected,
		"post bridge preserves RAX");
	Expect(
		dhooks_bridge_alignment == 8,
		"return resolver enters with SysV stack alignment");
	Expect(
		dhooks_bridge_key_matches == 1,
		"return resolver receives the original bridge stack key");

	const double doubleExpected = 173.625;
	Expect(
		Close(
			dhooks_bridge_run_double(postReturnAddress, doubleExpected),
			doubleExpected),
		"post bridge preserves XMM0");

	if (failures != 0)
	{
		std::printf("DHooks SysV bridge failed: %d\n", failures);
		return 1;
	}

	std::printf("DHooks SysV bridge passed\n");
	return 0;
}
