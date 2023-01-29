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

    round = function(n)
        return math.floor(n + 0.5)
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

    -- rotate the point (x, y) clockwise around (0, 0) by rad radians
    rotate2D = function(x, y, rad)
        return x * math.cos(rad) - y * math.sin(rad),
               x * math.sin(rad) + y * math.cos(rad)
    end,

    -- returns CW angle from in radians of line from point 1 to 2
    -- (or point 1 from origin if point 2 not provided)
    -- note: in game geometric system, i.e. positive y is down but angles are given relative to negative y ("north")
    lineAngle = function(x1, y1, x2, y2)
        if type(x1) ~= 'number' or type(y1) ~= 'number' then
            error('x1 and y1 must be supplied as numbers')
        end
        local dx, dy
        if x2 == nil and y2 == nil then
            dx, dy = x1, y1
        else
            if type(x2) ~= 'number' or type(y2) ~= 'number' then
                error('x2 and y2 must be supplied as numbers')
            end
            dx, dy = x2 - x1, y2 - y1
        end
        local refAngle = math.abs(math.atan(dy/dx))
        if dx == 0 then
            if dy <= 0 then
                return 0
            elseif dy > 0 then
                return math.pi
            end
        elseif dx > 0 then
            if dy >= 0 then
                return math.pi/2 + refAngle
            else
                return refAngle
            end
        else
            if dy <= 0 then
                return 3*math.pi/2 + refAngle
            else
                return math.pi + refAngle
            end
        end
    end,
}