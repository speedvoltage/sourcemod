#include <cstdarg>
#include <cstdint>

typedef float DHookVector __attribute__((vector_size(16)));

extern "C" __attribute__((noinline)) std::uint64_t
dhooks_hook_integer_target(std::uint64_t value)
{
	asm volatile(
		"nop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\n"
		"nop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\n");
	return value * 5 + 3;
}

extern "C" __attribute__((noinline)) double
dhooks_hook_double_target(double value)
{
	asm volatile(
		"nop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\n"
		"nop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\n");
	return value * 1.75 + 4.0;
}

extern "C" __attribute__((noinline)) double
dhooks_hook_override_target(double value)
{
	asm volatile(
		"nop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\n"
		"nop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\n");
	return value * 2.5 - 1.0;
}

extern "C" __attribute__((noinline)) std::uint64_t
dhooks_hook_mixed_target(
	std::uint64_t i0,
	double f0,
	std::uint64_t i1,
	double f1,
	std::uint64_t i2,
	double f2,
	std::uint64_t i3,
	double f3,
	std::uint64_t i4,
	double f4,
	std::uint64_t i5,
	double f5,
	std::uint64_t i6,
	double f6,
	double f7,
	double f8)
{
	asm volatile(
		"nop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\n"
		"nop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\n");
	return
		i0 +
		2 * i1 +
		3 * i2 +
		4 * i3 +
		5 * i4 +
		6 * i5 +
		7 * i6 +
		static_cast<std::uint64_t>(f0 + f1 + f2 + f3 + f4 + f5 + f6 + f7 + f8);
}

extern "C" __attribute__((noinline)) double
dhooks_hook_variadic_target(int count, ...)
{
	asm volatile(
		"nop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\n"
		"nop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\n");

	va_list args;
	va_start(args, count);
	double result = 0.0;
	for (int i = 0; i < count; i++)
		result += va_arg(args, double);
	va_end(args);
	return result;
}

extern "C" __attribute__((noinline)) std::uint64_t
dhooks_hook_wide_xmm_target(
	DHookVector v0,
	DHookVector v1,
	DHookVector v2,
	DHookVector v3,
	DHookVector v4,
	DHookVector v5,
	DHookVector v6,
	DHookVector v7)
{
	asm volatile(
		"nop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\n"
		"nop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\n");
	return static_cast<std::uint64_t>(
		(v0[0] + 2.0f * v0[1] + 4.0f * v0[2] + 8.0f * v0[3]) +
		2.0f * (v1[0] + 2.0f * v1[1] + 4.0f * v1[2] + 8.0f * v1[3]) +
		3.0f * (v2[0] + 2.0f * v2[1] + 4.0f * v2[2] + 8.0f * v2[3]) +
		4.0f * (v3[0] + 2.0f * v3[1] + 4.0f * v3[2] + 8.0f * v3[3]) +
		5.0f * (v4[0] + 2.0f * v4[1] + 4.0f * v4[2] + 8.0f * v4[3]) +
		6.0f * (v5[0] + 2.0f * v5[1] + 4.0f * v5[2] + 8.0f * v5[3]) +
		7.0f * (v6[0] + 2.0f * v6[1] + 4.0f * v6[2] + 8.0f * v6[3]) +
		8.0f * (v7[0] + 2.0f * v7[1] + 4.0f * v7[2] + 8.0f * v7[3]));
}
