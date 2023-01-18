import "util/enum"
local Enum <const> = util.enum
import "util/oo"
local typeGuard <const> = util.oo.typeGuard

util.set = {}
util.set.__index = util.set

local function construct(args)
    local set = {_values = {}}
    setmetatable(set, util.set)

    if args.type ~= nil then
        set._type = typeGuard('string', args.type)
    end
    if args.enum ~= nil then
        if not Enum.isEnum(args.enum) then error('set of enum constructed with non-enum') end
        set._enum = args.enum
    end
    for _, element in ipairs(args.values or {}) do
        set:add(element)
    end
    return set
end

function util.set.of(...)
    return construct{values = {...}}
end

function util.set.empty()
    return construct{}
end

function util.set.ofType(type, ...)
    return construct{type = type, values = {...}}
end

function util.set.ofEnum(enum, ...)
    return construct{enum = enum, values = {...}}
end

function util.set:add(element)
    if self._type ~= nil then
        typeGuard(self._type, element)
    end
    if self._enum ~= nil then
        self._enum:guard(element)
    end
    if element == nil then
        return
    end
    self._values[element] = true
    return self
end

function util.set:addAll(tbl)
    typeGuard('table', tbl)
    for _, e in ipairs(tbl) do
        self:add(e)
    end
    return self
end

function util.set:remove(element)
    if element == nil then
        return
    end
    self._values[element] = false
    return self
end
util.set.delete = util.set.remove

function util.set:clear()
    self._values = {}
end
util.set.removeAll = util.set.clear
util.set.deleteAll = util.set.clear

function util.set:values()
    local v = {}
    for value, ok in pairs(self._values) do
        if ok then table.insert(v, value) end
    end
    return v
end
util.set.getValues = util.set.values

function util.set:has(element)
    if element == nil then
        return false
    end
    return self._values[element] == true
end
util.set.contains = util.set.has
util.set.includes = util.set.has
