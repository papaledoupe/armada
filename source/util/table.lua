util = util or {}

util.table = {
    
    reversed = function(t)
        local rev = {}
        for i = #t, 1, -1 do
            table.insert(rev, t[i])
        end
        return rev
    end,

    hasValue = function(t, val)
        for _, v in pairs(t) do
            if v == val then
                return true
            end
        end
        return false
    end,

    joinValues = function(t, sep)
        local s = ''
        local first = true
        for k, v in pairs(t) do
            if not first then
                s = s .. sep
            end
            s = s.. tostring(t[k])
            first = false
        end
        return s
    end,

    readonly = function(t)
      local proxy = {}
      local len = #t
      local mt = {
            __index = t,
            __len = function(t)
                return len
            end,
            __newindex = function()
                error 'attempt to update a readonly table'
            end,
            __pairs = function()
                return next, t, nil
            end,
      }
      setmetatable(proxy, mt)
      return proxy
    end,

}

