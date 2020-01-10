fun ldexp(x : Float64, exp : LibC::Int) : Float64
  x * (1 << exp).to_f64
end
