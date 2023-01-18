util = util or {}

-- string utilities

util.string = {
    
    startsWith = function(str, start)
        return string.sub(str, 1, string.len(start)) == start
    end,

    split = function(str, sep)
        if sep == nil then
            sep = "%s"
        end
        local parts = {}
        for part in string.gmatch(str, "([^"..sep.."]+)") do
            table.insert(parts, part)
        end
        return parts
    end,

}

-- string extensions

local stringMetaTable = getmetatable("")

-- based on http://lua-users.org/wiki/StringInterpolation
-- usage: "my ${adjective} string" % {adjective="lovely"}
-- also supports array-like tables e.g. "my ${1} string" % {"lovely"}
function stringMetaTable:__mod(table)
    return self:gsub('($%b{})', function(w)
        local k = w:sub(3, -2)
        local nk = tonumber(k)
        return table[k] or (nk ~= nil and table[nk] or nil) or w
    end)
end

function stringMetaTable:__unm()
    local out = ''
    for line in self:gmatch("[^\r?\n]+") do
        local start = line:find('|')
        if start ~= nil then
            out = out .. line:sub(start + 1, #self) .. '\n'
        end
    end
    -- strip last newline
    if #out > 0 then
        out = out:sub(1, #out - 1)
    end
    return out
end

