#include "abi_oracle.h"

#include <cmath>
#include <cstdio>

#if defined(__GNUC__) || defined(__clang__)
# define DHOOKS_ABI_NOINLINE __attribute__((noinline))
#else
# define DHOOKS_ABI_NOINLINE
#endif

namespace {

int failures;
DHooksAbiReentrant volatile reentrant_target;

void Expect(bool condition, const char *name)
{
  std::printf("%s %s\n", condition ? "ok" : "not ok", name);
  if (!condition)
    failures++;
}

bool Close(float actual, float expected)
{
  return std::fabs(actual - expected) <= 0.00001f;
}

bool Close(double actual, double expected)
{
  return std::fabs(actual - expected) <= 0.000000001;
}

DHOOKS_ABI_NOINLINE std::uintptr_t Reenter(
    std::uintptr_t depth,
    std::uintptr_t value)
{
  return reentrant_target(depth, value, Reenter) + depth * 7 + 1;
}

}

int main()
{
  std::printf("DHooks ABI oracle: Linux %zu-bit\n", sizeof(void *) * 8);

  decltype(&dhooks_abi_scalar) volatile scalar = &dhooks_abi_scalar;
  Expect(scalar(9) == 20, "scalar argument and return");

  std::uint64_t pointer_value = 0x1122334455667788ULL;
  decltype(&dhooks_abi_pointer) volatile pointer = &dhooks_abi_pointer;
  Expect(pointer(&pointer_value) == &pointer_value, "pointer argument and return");

  decltype(&dhooks_abi_boolean) volatile boolean = &dhooks_abi_boolean;
  Expect(boolean(true) == false && boolean(false) == true, "bool argument and return");

  decltype(&dhooks_abi_float) volatile float_value = &dhooks_abi_float;
  Expect(Close(float_value(8.0f), 10.0f), "float argument and return");

  decltype(&dhooks_abi_double) volatile double_value = &dhooks_abi_double;
  Expect(Close(double_value(20.0), 8.0), "double argument and return");

  decltype(&dhooks_abi_mixed) volatile mixed = &dhooks_abi_mixed;
  Expect(
      mixed(2, 11.0f, 3, 13.0, 5, 17.0f, 7, 19.0) == 1257,
      "independent mixed GPR and SSE arguments");

  decltype(&dhooks_abi_gpr_spill) volatile gpr_spill = &dhooks_abi_gpr_spill;
  Expect(
      gpr_spill(2, 3, 5, 7, 11, 13, 17) == 303,
      "first GPR stack spill");

  decltype(&dhooks_abi_sse_spill) volatile sse_spill = &dhooks_abi_sse_spill;
  Expect(
      Close(sse_spill(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0), 285.0),
      "first SSE stack spill");

  decltype(&dhooks_abi_vector) volatile vector = &dhooks_abi_vector;
  DHooksAbiVector vector_result = vector(1.0f, 2.0f, 4.0f);
  Expect(
      Close(vector_result.x, 3.0f)
          && Close(vector_result.y, 6.0f)
          && Close(vector_result.z, 5.0f),
      "12-byte vector return");

  reentrant_target = &dhooks_abi_reentrant;
  Expect(
      reentrant_target(4, 100, Reenter) == 156,
      "nested reentrant calls");

  std::uintptr_t expected_stack_alignment = sizeof(void *) == 8 ? 8 : 12;
  Expect(
      dhooks_abi_entry_stack_mod16() == expected_stack_alignment,
      "entry stack alignment");

  Expect(
      dhooks_abi_check_callee_saved(
          &dhooks_abi_touch_callee_saved,
          0x13579bdfu) == 1,
      "callee-saved GPR preservation");

  if (failures != 0) {
    std::printf("DHooks ABI oracle failed: %d\n", failures);
    return 1;
  }

  std::printf("DHooks ABI oracle passed\n");
  return 0;
}
