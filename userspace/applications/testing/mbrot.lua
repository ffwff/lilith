-- The Computer Language Shootout
-- http://shootout.alioth.debian.org/
-- contributed by Mike Pall
-- with optimizations by Markus J. Q. (MarkusQ) Roberts

local width = tonumber(arg and arg[1]) or 100
local height, wscale = width, 2/width
local m, limit2 = 50, 4.0
local write, char = io.write, string.char

local h2 = math.floor(height/2)
local hm = height - h2*2
local top_half = {}

for y=0,h2+hm do
    local Ci = 2*y / height - 1
    local line = {""}
    for xb=0,width-1,8 do
        local bits = 0
        local xbb = xb+7
        for x=xb,xbb < width and xbb or width-1 do
            bits = bits + bits
            local Zr, Zi, Zrq, Ziq = 0.0, 0.0, 0.0, 0.0
            local Cr = x * wscale - 1.5
            local Zri = Zr*Zi
            for i=1,m/5 do
                Zr = Zrq - Ziq + Cr
                Zi = Zri + Zri + Ci
                Zri = Zr*Zi

                Zr = Zr*Zr - Zi*Zi + Cr
                Zi = 2*Zri +         Ci
                Zri = Zr*Zi

                Zr = Zr*Zr - Zi*Zi + Cr
                Zi = 2*Zri +         Ci
                Zri = Zr*Zi

                Zr = Zr*Zr - Zi*Zi + Cr
                Zi = 2*Zri +         Ci
                Zri = Zr*Zi

                Zr = Zr*Zr - Zi*Zi + Cr
                Zi = 2*Zri +         Ci
                Zri = Zr*Zi

                Zrq = Zr*Zr
                Ziq = Zi*Zi
                Zri = Zr*Zi
                if Zrq + Ziq > limit2 then
                    bits = bits + 1
                    break
                    end
                -- if i == 1 then
                --    local ar,ai       = 1-4*Zr,-4*Zi
                --    local a_r         = math.sqrt(ar*ar+ai*ai)
                --    local k           = math.sqrt(2)/2
                --    local br,bi2      = math.sqrt(a_r+ar)*k,(a_r-ar)/2
                --    if (br+1)*(br+1) + bi2 < 1 then
                --        break
                --        end
                --    end
                end
            end
        for x=width,xbb do 
            bits = bits + bits + 1 
            end
        table.insert(line,char(255-bits))
        end
    line = table.concat(line) 
    table.insert(top_half,line)
    end

write("P4\n", width, " ", height, "\n")
for y=1,h2+hm do
    write(top_half[y])
    end
for y=h2,1,-1 do
    write(top_half[y])
   end