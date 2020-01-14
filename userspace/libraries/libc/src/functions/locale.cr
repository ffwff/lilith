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

protected module Locale
  @@current_locale = uninitialized LibC::LConv
  @@flag = false

  def locale_ptr
    pointerof(@@current_locale)
  end

  def init_locale
    return if @@flag
    @@flag = true
    l = @@current_locale = uninitialized LibC::LConv
    l.decimal_point   = "."
    l.thousands_sep   = ""
    l.grouping        = ""
    l.int_curr_symbol = ""
    l.int_frac_digits = ""
    l.currency_symbol = ""
    l.mon_decimal_point = ""
    l.mon_grouping    = ""
    l.positive_sign   = "+"
    l.negative_sign   = "-"
    l.int_frac_digits = 255
    l.frac_digits     = 255
    l.p_cs_precedes   = 0
    l.p_sep_by_space  = 0
    l.p_sign_posn     = 0
    l.n_sign_posn     = 0
  end
end

fun localeconv : LibC::LConv*
  Locale.init_locale
  Locale.locale_ptr
end

fun setlocale(category : LibC::Int, locale : UInt8*) : UInt8*
  Pointer(Void).new(0)
end
