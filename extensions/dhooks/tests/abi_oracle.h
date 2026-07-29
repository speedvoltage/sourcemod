#ifndef _INCLUDE_SOURCEMOD_DHOOKS_TESTS_ABI_ORACLE_H_
#define _INCLUDE_SOURCEMOD_DHOOKS_TESTS_ABI_ORACLE_H_

#include <cstdint>

struct DHooksAbiVector
{
  float x;
  float y;
  float z;
};

using DHooksAbiReentrantCallback = std::uintptr_t (*)(std::uintptr_t, std::uintptr_t);
using DHooksAbiReentrant = std::uintptr_t (*)(
    std::uintptr_t,
    std::uintptr_t,
    DHooksAbiReentrantCallback);
using DHooksAbiCallee = std::uintptr_t (*)(std::uintptr_t);

extern "C" {
std::int32_t dhooks_abi_scalar(std::int32_t value);
void *dhooks_abi_pointer(void *value);
bool dhooks_abi_boolean(bool value);
float dhooks_abi_float(float value);
double dhooks_abi_double(double value);
std::uintptr_t dhooks_abi_mixed(
    std::uintptr_t integer1,
    float sse1,
    std::uintptr_t integer2,
    double sse2,
    std::uintptr_t integer3,
    float sse3,
    std::uintptr_t integer4,
    double sse4);
std::uintptr_t dhooks_abi_gpr_spill(
    std::uintptr_t value1,
    std::uintptr_t value2,
    std::uintptr_t value3,
    std::uintptr_t value4,
    std::uintptr_t value5,
    std::uintptr_t value6,
    std::uintptr_t value7);
double dhooks_abi_sse_spill(
    double value1,
    double value2,
    double value3,
    double value4,
    double value5,
    double value6,
    double value7,
    double value8,
    double value9);
DHooksAbiVector dhooks_abi_vector(float x, float y, float z);
std::uintptr_t dhooks_abi_reentrant(
    std::uintptr_t depth,
    std::uintptr_t value,
    DHooksAbiReentrantCallback callback);
std::uintptr_t dhooks_abi_touch_callee_saved(std::uintptr_t value);
std::uintptr_t dhooks_abi_entry_stack_mod16();
int dhooks_abi_check_callee_saved(DHooksAbiCallee callee, std::uintptr_t value);
}

#endif
