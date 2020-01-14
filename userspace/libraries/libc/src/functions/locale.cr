lib LibC
  struct LConv
    decimal_point : UInt8*
    thousands_sep : UInt8*
    grouping : UInt8*
    int_curr_symbol : UInt8*
    currency_symbol : UInt8*
    mon_decimal_point : UInt8*
    mon_thousands_sep : UInt8*
    mon_grouping : UInt8*
    positive_sign : UInt8*
    negative_sign : UInt8*
    int_frac_digits : UInt8
    frac_digits : UInt8
    p_cs_precedes : UInt8
    p_sep_by_space : UInt8
    n_cs_precedes : UInt8
    n_sep_by_space : UInt8
    p_sign_posn : UInt8
    n_sign_posn : UInt8
  end
end

module Locale
  extend self

  @@current_locale = LibC::LConv.new(
    decimal_point: ".",
    thousands_sep: "",
    grouping: "",
    int_curr_symbol: "",
    currency_symbol: "",
    mon_decimal_point: "",
    mon_thousands_sep: "",
    mon_grouping: "",
    positive_sign: "+",
    negative_sign: "-",
    int_frac_digits: 255,
    frac_digits: 255,
    p_cs_precedes: 0,
    p_sep_by_space: 0,
    n_cs_precedes: 0,
    n_sep_by_space: 0,
    p_sign_posn: 0,
    n_sign_posn: 0
  )

  def locale_ptr
    pointerof(@@current_locale)
  end
end

fun localeconv : LibC::LConv*
  Locale.locale_ptr
end

fun setlocale(category : LibC::Int, locale : UInt8*) : UInt8*
  Pointer(UInt8).new(0)
end
