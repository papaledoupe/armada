import "util/table"

util.enum = {}

util.enum.__index = util.enum

function util.enum.of(...)
    local values = {...}
    if #values == 0 then
        error('empty enum not allowed')
    end
    local enum = { values = {} }
    setmetatable(enum, util.enum)
    for _, value in ipairs(values) do
        enum.values[value] = value
    end
    return enum
end

function util.enum.isEnum(value)
    return getmetatable(value) == util.enum
end

-- combine values of multiple enums into new enum.
function util.enum.union(...)
    local enums = {...}
    local values = {}
    for _, enum in ipairs(enums) do
        for value, _ in pairs(enum.values) do
            table.insert(values, value)
        end
    end
    return util.enum.of(table.unpack(values))
end

function util.enum:guard(value)
    local existing = self.values[value]
    if existing == nil then
        error(tostring(value) .. ' is not a valid value for enum (values: ' .. util.table.joinValues(self.values, ', ') .. ')')
    end
    return value
end

function util.enum:has(value)
    return self.values[value] ~= nil
end

function util.enum:getValues()
    local values = {}
    for value, _ in pairs(self.values) do
        table.insert(values, value)
    end
    return values
end
util.enum.values = util.enum.getValues
