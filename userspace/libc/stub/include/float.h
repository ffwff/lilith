/* Characteristics of floating types <float.h>

   This file is part of the Public Domain C Library (PDCLib).
   Permission is granted to use, modify, and / or redistribute at will.
*/

#ifndef _PDCLIB_FLOAT_H
#define _PDCLIB_FLOAT_H _PDCLIB_FLOAT_H

#include "pdclib/_PDCLIB_config.h"

#define FLT_ROUNDS      _PDCLIB_FLT_ROUNDS
#define FLT_EVAL_METHOD _PDCLIB_FLT_EVAL_METHOD
#define DECIMAL_DIG     _PDCLIB_DECIMAL_DIG

   /* Radix of exponent representation */
#define FLT_RADIX      __FLT_RADIX__
   /* Number of base-FLT_RADIX digits in the significand of a float */
#define FLT_MANT_DIG   __FLT_MANT_DIG__
   /* Number of decimal digits of precision in a float */
#define FLT_DIG        __FLT_DIG__
   /* Difference between 1.0 and the minimum float greater than 1.0 */
#define FLT_EPSILON    __FLT_EPSILON__
   /* Minimum int x such that FLT_RADIX**(x-1) is a normalised float */
#define FLT_MIN_EXP    __FLT_MIN_EXP__
   /* Minimum normalised float */
#define FLT_MIN        __FLT_MIN__
   /* Minimum int x such that 10**x is a normalised float */
#define FLT_MIN_10_EXP __FLT_MIN_10_EXP__
   /* Maximum int x such that FLT_RADIX**(x-1) is a representable float */
#define FLT_MAX_EXP    __FLT_MAX_EXP__
   /* Maximum float */
#define FLT_MAX        __FLT_MAX__
   /* Maximum int x such that 10**x is a representable float */
#define FLT_MAX_10_EXP __FLT_MAX_10_EXP__

   /* Number of base-FLT_RADIX digits in the significand of a double */
#define DBL_MANT_DIG   __DBL_MANT_DIG__
   /* Number of decimal digits of precision in a double */
#define DBL_DIG        __DBL_DIG__
   /* Difference between 1.0 and the minimum double greater than 1.0 */
#define DBL_EPSILON    __DBL_EPSILON__
   /* Minimum int x such that FLT_RADIX**(x-1) is a normalised double */
#define DBL_MIN_EXP    __DBL_MIN_EXP__
   /* Minimum normalised double */
#define DBL_MIN        __DBL_MIN__
   /* Minimum int x such that 10**x is a normalised double */
#define DBL_MIN_10_EXP __DBL_MIN_10_EXP__
   /* Maximum int x such that FLT_RADIX**(x-1) is a representable double */
#define DBL_MAX_EXP    __DBL_MAX_EXP__
   /* Maximum double */
#define DBL_MAX        __DBL_MAX__
   /* Maximum int x such that 10**x is a representable double */
#define DBL_MAX_10_EXP __DBL_MAX_10_EXP__

   /* Number of base-FLT_RADIX digits in the significand of a long double */
#define LDBL_MANT_DIG   __LDBL_MANT_DIG__
   /* Number of decimal digits of precision in a long double */
#define LDBL_DIG        __LDBL_DIG__
   /* Difference between 1.0 and the minimum long double greater than 1.0 */
#define LDBL_EPSILON    __LDBL_EPSILON__
   /* Minimum int x such that FLT_RADIX**(x-1) is a normalised long double */
#define LDBL_MIN_EXP    __LDBL_MIN_EXP__
   /* Minimum normalised long double */
#define LDBL_MIN        __LDBL_MIN__
   /* Minimum int x such that 10**x is a normalised long double */
#define LDBL_MIN_10_EXP __LDBL_MIN_10_EXP__
   /* Maximum int x such that FLT_RADIX**(x-1) is a representable long double */
#define LDBL_MAX_EXP    __LDBL_MAX_EXP__
   /* Maximum long double */
#define LDBL_MAX        __LDBL_MAX__
   /* Maximum int x such that 10**x is a representable long double */
#define LDBL_MAX_10_EXP __LDBL_MAX_10_EXP__

#endif
