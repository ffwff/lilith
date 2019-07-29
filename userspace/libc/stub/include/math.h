#ifndef _LIBC_MATH_H
#define _LIBC_MATH_H

double fabs(double arg);

double sin(double arg);
double cos(double arg);
double tan(double arg);

double sinh(double arg);
double cosh(double arg);
double tanh(double arg);

double asin(double arg);
double acos(double arg);
double atan(double arg);
double atan2(double y, double x);

double asinh(double arg);
double acosh(double arg);
double atanh(double arg);

double exp(double arg);
double log(double arg);
double log2(double arg);
double log10(double arg);

double sqrt(double arg);
double cbrt(double arg);
double ldexp(double arg, int exp);
double hypot(double arg, int exp);
double pow(double base, double exponent);

double erf(double x);
double erfc(double x);

double floor(double arg);
double ceil(double arg);
double round(double arg);

double fmod(double, double);

double frexp(double, int *);

#define FP_NAN       0
#define FP_INFINITE  1
#define FP_ZERO      2
#define FP_SUBNORMAL 3
#define FP_NORMAL    4

int __fpclassify(double);
int __fpclassifyf(float);
int __fpclassifyl(long double);

static __inline unsigned __FLOAT_BITS(float __f)
{
    union {float __f; unsigned __i;} __u;
    __u.__f = __f;
    return __u.__i;
}
static __inline unsigned long long __DOUBLE_BITS(double __f)
{
    union {double __f; unsigned long long __i;} __u;
    __u.__f = __f;
    return __u.__i;
}

#define fpclassify(x) ( \
    sizeof(x) == sizeof(float) ? __fpclassifyf(x) : \
    sizeof(x) == sizeof(double) ? __fpclassify(x) : \
    __fpclassifyl(x) )

#define isinf(x) ( \
    sizeof(x) == sizeof(float) ? (__FLOAT_BITS(x) & 0x7fffffff) == 0x7f800000 : \
    sizeof(x) == sizeof(double) ? (__DOUBLE_BITS(x) & -1ULL>>1) == 0x7ffULL<<52 : \
    __fpclassifyl(x) == FP_INFINITE)

#define isnan(x) ( \
    sizeof(x) == sizeof(float) ? (__FLOAT_BITS(x) & 0x7fffffff) > 0x7f800000 : \
    sizeof(x) == sizeof(double) ? (__DOUBLE_BITS(x) & -1ULL>>1) > 0x7ffULL<<52 : \
    __fpclassifyl(x) == FP_NAN)

#define isnormal(x) ( \
    sizeof(x) == sizeof(float) ? ((__FLOAT_BITS(x)+0x00800000) & 0x7fffffff) >= 0x01000000 : \
    sizeof(x) == sizeof(double) ? ((__DOUBLE_BITS(x)+(1ULL<<52)) & -1ULL>>1) >= 1ULL<<53 : \
    __fpclassifyl(x) == FP_NORMAL)

#define isfinite(x) ( \
    sizeof(x) == sizeof(float) ? (__FLOAT_BITS(x) & 0x7fffffff) < 0x7f800000 : \
    sizeof(x) == sizeof(double) ? (__DOUBLE_BITS(x) & -1ULL>>1) < 0x7ffULL<<52 : \
    __fpclassifyl(x) > FP_INFINITE)

#if 100 * __GNUC__ + __GNUC_MINOR__ >= 303
#define NAN __builtin_nanf("")
#define INFINITY __builtin_inff()
#else
#define NAN (0.0f / 0.0f)
#define INFINITY 1e5000f
#endif

int __signbit(double);
int __signbitf(float);
int __signbitl(long double);

#define signbit(x) ( \
    sizeof(x) == sizeof(float) ? (int)(__FLOAT_BITS(x)>>31) : \
    sizeof(x) == sizeof(double) ? (int)(__DOUBLE_BITS(x)>>63) : \
    __signbitl(x) )

#endif