util = util or {}

-- math utilities


-- stolen from http://lua-users.org/wiki/IntegerDomain
function intlimit()
  local floor = math.floor

  -- get highest power of 2 which Lua can still handle as integer
  local step = 2
  while true do
    local nextstep = step*2
    if nextstep-(nextstep-1) == 1 and nextstep > 0 then
      step = nextstep
    else
      break
    end
  end

  -- now get the highest number which Lua can still handle as integer
  local limit,step = step,floor(step/2)
  while step > 0 do
    local nextlimit = limit+step
    if nextlimit-(nextlimit-1) == 1 and nextlimit > 0 then
      limit = nextlimit
    end
    step = floor(step/2)
  end
  return limit
end

util.math = {

    MaxInteger = intlimit(),
    
    isNaN = function(n)
        return type(n) == 'number' and n ~= n
    end,

    -- clamp n between min and max, inclusive
    clamp = function(n, min, max)
        return math.max(math.min(n, max), min)
    end,

    -- as clamp, but when n < min, n becomes max, and vice versa
    cycle = function(n, min, max)
        if n > max then return min
        elseif n < min then return max
        else return n
        end
    end,

    -- collapses signed number to unsigned
    ZtoN = function(n)
        if type(n) ~= 'number' then error(tostring(n)..' is not a number') end
        n = math.floor(n)
        if n > util.math.MaxInteger / 4 then
            error(tostring(n)..' is too large for ZtoN')
        end
        if n >= 0 then 
            return n * 2 
        else 
            return (n * -2) - 1 
        end
    end,

    NtoZ = function(z)
        if type(z) ~= 'number' or z < 0 then error(tostring(z)..' is not a natural number') end
        z = math.floor(z)
        if z % 2 == 0 then 
            return z / 2 
        else 
            return (z + 1) / -2
        end
    end,

    -- bijective {Z, Z} => Z mapping (Z integer)
    -- essentially a cantor function with an additional mapping to support negative integers
    pair = function(a, b)
        a = util.math.ZtoN(a)
        b = util.math.ZtoN(b)
        return math.floor((((a + b) * (a + b + 1)) / 2) + b)
    end,

    -- reverse of pair
    unpair = function(n)
        -- https://en.wikipedia.org/wiki/Pairing_function#Inverting_the_Cantor_pairing_function
        local w = math.floor((math.sqrt((8 * n) + 1) - 1) / 2)
        local t = (w * (w + 1)) / 2
        local b = n - t
        local a = w - b
        return util.math.NtoZ(a), util.math.NtoZ(b)
    end,
}