#include "abi_oracle.h"

#if defined(__GNUC__) || defined(__clang__)
# define DHOOKS_ABI_NOINLINE __attribute__((noinline))
#else
# define DHOOKS_ABI_NOINLINE
#endif

static_assert(sizeof(DHooksAbiVector) == 12);

extern "C" DHOOKS_ABI_NOINLINE std::int32_t
dhooks_abi_scalar(std::int32_t value)
{
  return value * 3 - 7;
}

extern "C" DHOOKS_ABI_NOINLINE void *
dhooks_abi_pointer(void *value)
{
  return value;
}

extern "C" DHOOKS_ABI_NOINLINE bool
dhooks_abi_boolean(bool value)
{
  return !value;
}

extern "C" DHOOKS_ABI_NOINLINE float
dhooks_abi_float(float value)
{
  return value * 1.5f - 2.0f;
}

extern "C" DHOOKS_ABI_NOINLINE double
dhooks_abi_double(double value)
{
  return value * 0.25 + 3.0;
}

extern "C" DHOOKS_ABI_NOINLINE std::uintptr_t
dhooks_abi_mixed(
    std::uintptr_t integer1,
    float sse1,
    std::uintptr_t integer2,
    double sse2,
    std::uintptr_t integer3,
    float sse3,
    std::uintptr_t integer4,
    double sse4)
{
  return integer1 * 3
       + integer2 * 5
       + integer3 * 7
       + integer4 * 11
       + static_cast<std::uintptr_t>(sse1 * 13.0f)
       + static_cast<std::uintptr_t>(sse2 * 17.0)
       + static_cast<std::uintptr_t>(sse3 * 19.0f)
       + static_cast<std::uintptr_t>(sse4 * 23.0);
}

extern "C" DHOOKS_ABI_NOINLINE std::uintptr_t
dhooks_abi_gpr_spill(
    std::uintptr_t value1,
    std::uintptr_t value2,
    std::uintptr_t value3,
    std::uintptr_t value4,
    std::uintptr_t value5,
    std::uintptr_t value6,
    std::uintptr_t value7)
{
  return value1
       + value2 * 2
       + value3 * 3
       + value4 * 4
       + value5 * 5
       + value6 * 6
       + value7 * 7;
}

extern "C" DHOOKS_ABI_NOINLINE double
dhooks_abi_sse_spill(
    double value1,
    double value2,
    double value3,
    double value4,
    double value5,
    double value6,
    double value7,
    double value8,
    double value9)
{
  return value1
       + value2 * 2.0
       + value3 * 3.0
       + value4 * 4.0
       + value5 * 5.0
       + value6 * 6.0
       + value7 * 7.0
       + value8 * 8.0
       + value9 * 9.0;
}

extern "C" DHOOKS_ABI_NOINLINE DHooksAbiVector
dhooks_abi_vector(float x, float y, float z)
{
  return {x + y, y + z, z + x};
}

extern "C" DHOOKS_ABI_NOINLINE std::uintptr_t
dhooks_abi_reentrant(
    std::uintptr_t depth,
    std::uintptr_t value,
    DHooksAbiReentrantCallback callback)
{
  if (depth == 0)
    return value;
  return callback(depth - 1, value + depth);
}

extern "C" DHOOKS_ABI_NOINLINE std::uintptr_t
dhooks_abi_touch_callee_saved(std::uintptr_t value)
{
#if defined(__x86_64__)
  __asm__ volatile("" : : "r"(value) : "rbx", "r12", "r13", "r14", "r15");
#elif defined(__i386__)
  __asm__ volatile("" : : "r"(value) : "ebx", "esi", "edi");
#endif
  return value ^ static_cast<std::uintptr_t>(0x5a5aa5a5u);
}

#if defined(__x86_64__)
__asm__(
    ".text\n"
    ".globl dhooks_abi_entry_stack_mod16\n"
    ".type dhooks_abi_entry_stack_mod16,@function\n"
    "dhooks_abi_entry_stack_mod16:\n"
    "mov %rsp,%rax\n"
    "and $15,%rax\n"
    "ret\n"
    ".size dhooks_abi_entry_stack_mod16,.-dhooks_abi_entry_stack_mod16\n"
    ".globl dhooks_abi_check_callee_saved\n"
    ".type dhooks_abi_check_callee_saved,@function\n"
    "dhooks_abi_check_callee_saved:\n"
    "push %rbx\n"
    "push %rbp\n"
    "push %r12\n"
    "push %r13\n"
    "push %r14\n"
    "push %r15\n"
    "sub $8,%rsp\n"
    "mov %rdi,%rax\n"
    "mov %rsi,%rdi\n"
    "movabs $0x1122334455667788,%rbx\n"
    "movabs $0x8877665544332211,%rbp\n"
    "movabs $0x0123456789abcdef,%r12\n"
    "movabs $0xfedcba9876543210,%r13\n"
    "movabs $0x0f1e2d3c4b5a6978,%r14\n"
    "movabs $0x89abcdef01234567,%r15\n"
    "call *%rax\n"
    "mov $1,%eax\n"
    "movabs $0x1122334455667788,%r10\n"
    "cmp %r10,%rbx\n"
    "jne 1f\n"
    "movabs $0x8877665544332211,%r10\n"
    "cmp %r10,%rbp\n"
    "jne 1f\n"
    "movabs $0x0123456789abcdef,%r10\n"
    "cmp %r10,%r12\n"
    "jne 1f\n"
    "movabs $0xfedcba9876543210,%r10\n"
    "cmp %r10,%r13\n"
    "jne 1f\n"
    "movabs $0x0f1e2d3c4b5a6978,%r10\n"
    "cmp %r10,%r14\n"
    "jne 1f\n"
    "movabs $0x89abcdef01234567,%r10\n"
    "cmp %r10,%r15\n"
    "jne 1f\n"
    "jmp 2f\n"
    "1:\n"
    "xor %eax,%eax\n"
    "2:\n"
    "add $8,%rsp\n"
    "pop %r15\n"
    "pop %r14\n"
    "pop %r13\n"
    "pop %r12\n"
    "pop %rbp\n"
    "pop %rbx\n"
    "ret\n"
    ".size dhooks_abi_check_callee_saved,.-dhooks_abi_check_callee_saved\n");
#elif defined(__i386__)
__asm__(
    ".text\n"
    ".globl dhooks_abi_entry_stack_mod16\n"
    ".type dhooks_abi_entry_stack_mod16,@function\n"
    "dhooks_abi_entry_stack_mod16:\n"
    "mov %esp,%eax\n"
    "and $15,%eax\n"
    "ret\n"
    ".size dhooks_abi_entry_stack_mod16,.-dhooks_abi_entry_stack_mod16\n"
    ".globl dhooks_abi_check_callee_saved\n"
    ".type dhooks_abi_check_callee_saved,@function\n"
    "dhooks_abi_check_callee_saved:\n"
    "mov 4(%esp),%eax\n"
    "mov 8(%esp),%ecx\n"
    "push %ebx\n"
    "push %ebp\n"
    "push %esi\n"
    "push %edi\n"
    "sub $8,%esp\n"
    "push %ecx\n"
    "mov $0x11223344,%ebx\n"
    "mov $0x88776655,%ebp\n"
    "mov $0x01234567,%esi\n"
    "mov $0x89abcdef,%edi\n"
    "call *%eax\n"
    "add $12,%esp\n"
    "mov $1,%eax\n"
    "cmp $0x11223344,%ebx\n"
    "jne 1f\n"
    "cmp $0x88776655,%ebp\n"
    "jne 1f\n"
    "cmp $0x01234567,%esi\n"
    "jne 1f\n"
    "cmp $0x89abcdef,%edi\n"
    "jne 1f\n"
    "jmp 2f\n"
    "1:\n"
    "xor %eax,%eax\n"
    "2:\n"
    "pop %edi\n"
    "pop %esi\n"
    "pop %ebp\n"
    "pop %ebx\n"
    "ret\n"
    ".size dhooks_abi_check_callee_saved,.-dhooks_abi_check_callee_saved\n");
#endif
