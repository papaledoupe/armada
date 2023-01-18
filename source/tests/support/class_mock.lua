testSupport = testSupport or {}

-- pass in table of public fields / methods
-- just enough to pass instanceOf/typeGuard checks
testSupport.classMock = function(name, tbl)
    tbl = tbl or {}
    local instance = {
        instance_of = function(self, cls)
            return name == cls
        end,
        get_name = function(self)
            return name
        end,
    }
    for k, v in pairs(tbl) do
        instance[k] = v
    end
    setmetatable(instance, {
        __index = function(t, k)
            error('attempted to read undefined key '..k..' on mock of '..name)
        end,
        __newindex = function(t, k, v)
            error('attempted to write undefined key '..k..' on mock of '..name..' to value '..tostring(v))
        end,
    })
    return instance
end
