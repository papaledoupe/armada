-- OO utilities on top of simploo lib

import "lib/simploo/simploo"

util = util or {}
util.oo = {}

-- true if the value is an instance of the given class or a class which inherits from it
function util.oo.instanceOf(className, value)
    if type(value) ~= "table" then return false end
    if value.instance_of == nil then return false end
    return value:instance_of(className)
end

--[[
    usage:

    interface "Name" {
        "methodNameA",
        "methodNameB",
        static = { ... }
    }

    bit of a hack, but gains the functionality of simploo without temptation to fall back on overusing
    abstract base classes.
]]
function util.oo.interface(name)
    return function(methodNamesWithExtras)
        local classBody = {
            __construct = function() 
                error('cannot call constructor of interface type '..name)
            end,
            static(methodNamesWithExtras.static or {})
        }

        for k, v in pairs(methodNamesWithExtras) do
            if type(k) == 'number' then
                local methodName = v
                classBody[methodName] = function() 
                    error('method '..methodName..' is not implemented in interface type '..name) 
                end
            end
        end
        return class(name)(classBody)
    end
end

function util.oo.valueobject(name)
    return function(definitionWithExtras)
        local definition = {}
        local computedFields = definitionWithExtras.computed or {}
        for k, v in pairs(definitionWithExtras) do
            if type(k) == 'string' then
                if k ~= 'static' and k ~= 'computed' then
                    definition[k] = v
                end
            end
        end
        local fields = {}
        for k, _ in pairs(definition) do
            fields[k] = null
        end
        for k, _ in pairs(computedFields) do
            fields[k] = null
        end
        return class(name)({
            public {
                __construct = function(self, args)
                    args = args or {}
                    for k, options in pairs(definition) do
                        local t = options.type
                        local def = options.default
                        local validator = options.validate
                        local array = options.array or false
                        local value = nil
                        if def == nil then
                            value = args[k]
                            if value == nil then
                                error('field '..k..' is required as it has no default')
                            end
                        elseif def == null then
                            value = args[k] or nil
                        else
                            value = args[k] or def
                        end
                        if type(t) == 'string' and value ~= nil then
                            local valueCheck = function(value, type)
                                local ok, err = pcall(function()
                                    util.oo.typeGuard(type, value)
                                end)
                                if not ok then
                                    error('field '..k..': '..err)
                                end
                            end
                            if array then
                                valueCheck(value, 'table')
                                for _, v in ipairs(value) do
                                    valueCheck(v, t)
                                end
                            else
                                valueCheck(value, t)
                            end
                        end
                        if validator ~= nil and not validator(value) then
                            error('validation failed for field '..k)
                        end
                        self[k] = value
                    end
                    for k, compute in pairs(computedFields) do
                        self[k] = compute(self)
                    end
                end,
                static(definitionWithExtras.static or {})
            },
            private {
                getter(fields)
            },
        })
    end
end

function util.oo.typeGuard(typeOrClass, value)
    local actualType = type(value)
    if type(value) == typeOrClass then 
        return value
    end
    if type(value) == 'table' and value.instance_of ~= nil then
        actualType = value:get_name()
        if util.oo.instanceOf(typeOrClass, value) then
            return value
        end
    end
    error('type guard failed: expected type '..typeOrClass..', was '..actualType)
end

function util.oo.typeGuardElements(typeOrClass, table)
    util.oo.typeGuard('table', table)
    for _, el in ipairs(table) do
        util.oo.typeGuard(typeOrClass, el)
    end
    return table
end

