#include <cstdarg>
#include <cstdint>

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
