function erato(n)
  if n < 2 then return {} end
  local t = {0} -- clears '1'
  local sqrtlmt = math.sqrt(n)
  for i = 2, n do t[i] = 1 end
  for i = 2, sqrtlmt do if t[i] ~= 0 then for j = i*i, n, i do t[j] = 0 end end end
  local primes = {}
  for i = 2, n do if t[i] ~= 0 then table.insert(primes, i) end end
  return primes
end

print("Input a number: ")
n = io.read("*n")
print("Primes up to ", n, ":\n")
for k in pairs(erato(n)) do
  print(k)
end