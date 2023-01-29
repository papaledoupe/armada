local lu <const> = import 'lib/luaunit/luaunit'
import 'util/oo'
import 'lib/simploo/simploo'
local oo <const> = util.oo

class "Foo" {
    public {
        foo = function() return "foo" end
    }
}
class "Bar" {
    public {
        bar = function() return "bar" end
    }
}
class "Baz" extends "Foo" {
    public {
        baz = function() return "baz" end
    }
}
class "Quux" extends "Foo, Bar" {
    public {
        baz = function() return "baz" end
    }
}

TestInstanceOf = {
    
    testArgsThatArentEvenTables = function()
        lu.assertFalse(oo.instanceOf("Foo", nil))
        lu.assertFalse(oo.instanceOf("Foo", 1))
        lu.assertFalse(oo.instanceOf("Foo", "Foo"))
        lu.assertFalse(oo.instanceOf("Foo", true))
    end,

    testArgsThatAreTablesButNotClasses = function()
        lu.assertFalse(oo.instanceOf("Foo", {}))
        lu.assertFalse(oo.instanceOf("Foo", {foo="foo"}))
    end,

    testArgsThatAreClassesButNotRightClasses = function()
        lu.assertFalse(oo.instanceOf("Foo", Bar.new()))
        lu.assertFalse(oo.instanceOf("Bar", Baz.new()))
    end,

    testArgsThatAreSameClass = function()
        lu.assertTrue(oo.instanceOf("Foo", Foo.new()))
    end,

    testArgsThatInheritFromClass = function()
        lu.assertTrue(oo.instanceOf("Foo", Baz.new()))
        lu.assertTrue(oo.instanceOf("Foo", Quux.new()))
        lu.assertTrue(oo.instanceOf("Bar", Quux.new()))
    end,

}

oo.interface "InterfaceType" {
    "interfaceMethodA",
    "interfaceMethodB",
    static = {
        staticField = 123,
        staticFn = function(self, mul)
            return self.staticField * mul
        end,
    }
}
class "Implementer" extends "InterfaceType" {
    public {
        interfaceMethodA = function() return "ok" end,
    },
}

TestInterface = {

    testInterfaceCannotBeConstructed = function()
        lu.assertErrorMsgContains("cannot call constructor of interface type InterfaceType", function() 
            InterfaceType.new()
        end)
    end,

    testInterfaceMethodCannotBeCalled = function()
        lu.assertErrorMsgContains(" method interfaceMethodB is not implemented in interface type InterfaceType", function() 
            Implementer.new():interfaceMethodB()
        end)
    end,

    testExtendedInterfaceMethod = function()
        lu.assertEquals(Implementer.new():interfaceMethodA(), "ok")
    end,

    testInterfaceExtenderIsInstanceOfInterface = function()
        lu.assertTrue(oo.instanceOf("InterfaceType", Implementer.new()))
    end,

    testInterfaceStaticFieldOnInterface = function()
        lu.assertEquals(InterfaceType.staticField, 123)
        lu.assertEquals(InterfaceType:staticFn(2), 246)
    end,

    testInterfaceStaticFieldOnInterfaceImplementer = function()
        lu.assertEquals(Implementer.staticField, 123)
        lu.assertEquals(Implementer:staticFn(2), 246)
    end,
}

TestTypeGuard = {

    testTypeGuardFails = function()
        for _, testCase in pairs{
            { 'string', 1, 'number'},
            { 'string', true, 'boolean' },
            { 'Foo', 'str', 'string' },
            { 'table', true, 'boolean' },
            { 'Bar', Baz.new(), 'Baz' },
        } do 
            local wrongType, value, actualType = table.unpack(testCase)
            lu.assertErrorMsgContains("type guard failed: expected type "..wrongType..", was "..actualType, function() 
                oo.typeGuard(wrongType, value)
            end)
        end
    end,

    testTypeGuardSucceeds = function()
        for _, testCase in pairs{
            { 'string', 'foo' },
            { 'boolean', true },
            { 'number', 4 },
            { 'table', {1} },
            { 'Foo', Foo.new() },
            { 'table', Foo.new() },
            { 'Foo', Baz.new() },
        } do 
            local type, value = table.unpack(testCase)
            lu.assertEquals(oo.typeGuard(type, value), value)
        end
    end,

    testTypeGuardElementsFails = function()
        for _, testCase in pairs{
            { 'table', 1, 'number'},
            { 'string', {1}, 'number'},
            { 'string', {true}, 'boolean' },
            { 'boolean', {true, 1}, 'number' },
            { 'Foo', {'str'}, 'string' },
            { 'table', {true}, 'boolean' },
            { 'Bar', {Baz.new()}, 'Baz' },
        } do 
            local wrongType, value, actualType = table.unpack(testCase)
            lu.assertErrorMsgContains("type guard failed: expected type "..wrongType..", was "..actualType, function() 
                oo.typeGuardElements(wrongType, value)
            end)
        end
    end,

    testTypeGuardElementsSucceeds = function()
        for _, testCase in pairs{
            { 'string', {'foo', 'bar'} },
            { 'boolean', {true, false} },
            { 'number', {4} },
            { 'table', {{1}} },
            { 'Foo', {Foo.new()} },
            { 'table', {Foo.new(), {}} },
            { 'Foo', {Foo.new(), Baz.new()} },
        } do 
            local type, value = table.unpack(testCase)
            lu.assertEquals(oo.typeGuardElements(type, value), value)
        end
    end,

    testTypeGuardKeysValuesSucceeds = function()
        for _, testCase in pairs{
            { 'string', 'string', {} },
            { 'string', 'string', {foo = 'a', bar = 'b'} },
            { 'string', 'boolean', {foo = true, ['bar'] = false} },
            { 'number', 'number', {1, 2, 3}},
            { 'number', 'number', {[1] = 2, [4] = 6}},
            { 'table', 'number', {[{1}] = 2, [{2}] = 6}},
            { 'number', 'Foo', {Foo.new(), Baz.new()} },
        } do 
            local keyT, valueT, tbl = table.unpack(testCase)
            lu.assertEquals(oo.typeGuardKeysValues(keyT, valueT, tbl), tbl)
        end
    end,

    testTypeGuardKeysValuesFails = function()
        for _, testCase in pairs{
            { 'string', 'string', {1} },
            { 'string', 'string', {foo = 'a', bar = 2} },
            { 'string', 'boolean', {foo = true, ['bar'] = 'false'} },
            { 'number', 'number', {1, 2, '3'}},
            { 'number', 'Foo', {Foo.new(), Bar.new()} },
        } do 
            local keyT, valueT, tbl = table.unpack(testCase)
            lu.assertError(function() 
                oo.typeGuardKeysValues(keyT, valueT, tbl)
            end)
        end
    end,
}

oo.valueobject "MyValue" {
    a = { type = 'string', default = 'def' },
    b = { type = 'number' }
}

oo.valueobject "NullDefault" {
    f = { type = 'string', default = null },
}

oo.valueobject "Validating" {
    a = { type = 'string', validate = function(s) return #s > 3 end }
}

oo.valueobject "WithStatics" {
    field = { type = 'string' },
    static = {
        staticField = 1,
        staticFunc = function(WithStatics)
            return WithStatics.staticField + 1
        end,

        staticFactory = function(WithStatics, field)
            return WithStatics.new{field = field}
        end,
    }
}

oo.valueobject "WithArray" {
    field = { 
        type = 'string', 
        array = true, 
        validate = function(a) 
            return #a < 3 
        end,
        default = {'str'},
    },
}

oo.valueobject "WithComputed" {
    a = { type = 'number' },
    b = { type = 'number' },
    computed = {
        c = function(self) 
            return self.a + self.b
        end,
    }
}

TestValueObject = {
    testValueObjectRequiresFieldsWithoutDefaultInConstructor = function()
        lu.assertErrorMsgContains('b is required', function() MyValue.new() end)
    end,

    testValueObjectTypeChecking = function()
        lu.assertErrorMsgContains('field b', function() MyValue.new{b = 'str'} end)
        lu.assertErrorMsgContains('type guard failed', function() MyValue.new{b = 'str'} end)
        lu.assertErrorMsgContains('field a', function() MyValue.new{b = 1, a = 1} end)
        lu.assertErrorMsgContains('type guard failed', function() MyValue.new{b = 1, a = 1} end)
    end,

    testValueObjectFieldsGetDefaultValues = function()
        local instance = MyValue.new{b = 4}
        lu.assertEquals(instance.a, 'def')
    end,

    testValueObjectFieldsGetGivenValues = function()
        local instance = MyValue.new{a = 'str', b = 4}
        lu.assertEquals(instance.a, 'str')
        lu.assertEquals(instance.b, 4)
    end,

    testValueObjectImmutable = function()
        local instance = MyValue.new{a = 'str', b = 4}
        lu.assertErrorMsgContains('accessing private', function() instance.a = 'otherstr' end)
    end,

    testNullDefault = function()
        local instance = NullDefault.new()
        lu.assertNil(instance.f)

        instance = NullDefault.new{f = nil}
        lu.assertNil(instance.f)        
    end,

    testValidationSuccess = function()
        Validating.new{a = 'foobar'}
    end,

    testValidationFail = function()
        lu.assertErrorMsgContains('validation failed for field a', function() 
            Validating.new{a = 'foo'}
        end)
    end,

    testStaticFields = function()
        lu.assertEquals(WithStatics.staticField, 1)
        lu.assertEquals(WithStatics:staticFunc(), 2)
        WithStatics.staticField = 4
        lu.assertEquals(WithStatics:staticFunc(), 5)
        lu.assertEquals(WithStatics:staticFactory('str').field, WithStatics.new{field = 'str'}.field)
    end,

    testArrayField = function()
        lu.assertEquals(WithArray.new{field = {'a', 'b'}}.field, {'a', 'b'})
        lu.assertErrorMsgContains('expected type table, was number', function()
            WithArray.new{field = 1}
        end)
        lu.assertErrorMsgContains('expected type string, was number', function()
            WithArray.new{field = {1}}
        end)
        lu.assertErrorMsgContains('expected type string, was number', function()
            WithArray.new{field = {'1', 2}}
        end)
    end,

    testArrayFieldValidation = function()
        lu.assertErrorMsgContains('validation failed for field field', function()
            -- due to length < 3 check
            WithArray.new{field = {'a', 'b', 'c'}}
        end)
    end,

    testArrayFieldDefault = function()
        lu.assertEquals(WithArray.new().field, {'str'})
    end,

    testComputedFields = function()
        local vo = WithComputed.new{a = 3, b = 2}
        lu.assertEquals(vo.c, 5)
    end,

    testComputedFieldsIgnoredInConstructor = function()
        local vo = WithComputed.new{a = 3, b = 2, c = 4}
        lu.assertEquals(vo.c, 5)
    end,
}

