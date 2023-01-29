import 'util/oo'
local typeGuard <const> = util.oo.typeGuard

util.memo = function(f, opts)
    typeGuard('function', f)
    opts = typeGuard('table', opts or {})
    local extractKeys = typeGuard('function', opts.extractKeys or function(...) return {...} end)

    local lastKeys = {'__memo_not_called'}
    local memo = nil
    return function(...)
        local newArgs = {...}
        local diff = true
        local newKeys = extractKeys(table.unpack(newArgs))
        if #lastKeys == #newKeys then
            if #lastKeys == 0 then
                diff = false
            else
                for i, newKey in ipairs(newKeys) do
                    if newKey ~= lastKeys[i] then
                        break
                    end
                    if i == #newKeys then
                        diff = false
                    end
                end
            end
        end
        if not diff then
            return table.unpack(memo)
        end
        lastKeys = newKeys
        memo = table.pack(f(table.unpack(newArgs)))
        return table.unpack(memo)
    end
end
