local lu <const> = import 'lib/luaunit/luaunit'
import 'util/set'
local Set <const> = util.set
import 'util/enum'
local Enum <const> = util.enum

class "SetMember" {
    public {
        data = '',
        __construct = function(self, data) self.data = data end,
    }
}

TestSet = {

    testHasValues = function()
        local s = Set.of(1, 2, "sausage")
        lu.assertTrue(s:has(1))
        lu.assertTrue(s:has(2))
        lu.assertTrue(s:has("sausage"))
        lu.assertFalse(s:has(nil))
        lu.assertFalse(s:has(3))
    end,

    testHasAliases = function()
        local s = Set.of(1, 2, "sausage")
        lu.assertTrue(s:includes(1))
        lu.assertTrue(s:contains(2))
    end,

    testAddAndRemoveValues = function()
        local s = Set.empty()
        lu.assertFalse(s:has(1))
        s:add(1)
        lu.assertTrue(s:has(1))
        lu.assertFalse(s:has(2))
        s:add(2)
        lu.assertTrue(s:has(2))
        s:remove(2)
        lu.assertTrue(s:has(1))
        lu.assertFalse(s:has(2))
    end,

    testAddAll = function()
        local s = Set.empty()
        local ret = s:addAll{1, 2, 3}
        lu.assertEquals(ret, s)
        lu.assertTrue(ret:has(1))
        lu.assertTrue(ret:has(2))
        lu.assertTrue(ret:has(3))
        lu.assertFalse(ret:has(4))
    end,

    testRemoveAndAdd = function()
        local s = Set.empty()
        s:remove(1)
        lu.assertFalse(s:has(1))
        local ret = s:add(1)
        lu.assertEquals(ret, s)
        lu.assertTrue(s:has(1))
    end,

    testValues = function()
        local values = Set.empty():add(1):add(2):add(3):remove(2):values()
        lu.assertEquals(#values, 2)
        lu.assertTableContains(values, 1)
        lu.assertTableContains(values, 3)
    end,

    testRemoveAliases = function()
        local s = Set.empty()
        s:add(1)
        lu.assertTrue(s:has(1))
        s:delete(1)
        lu.assertFalse(s:has(1))
    end,

    testCanCallAddWithNilButNilIsNotInSet = function()
        local s = Set.empty()
        lu.assertFalse(s:has(nil))
        s:add(nil)
        lu.assertFalse(s:has(nil))
    end,

    testClear = function()
        local s = Set.of(1, 2, 3)
        s:clear()
        lu.assertFalse(s:has(1))
        lu.assertFalse(s:has(2))
        lu.assertFalse(s:has(3))
    end,

    testTyped = function()
        local s = Set.ofType('string')
        s:add("str")
        lu.assertTrue(s:has("str"))
        lu.assertErrorMsgContains('type guard failed', function() s:add(nil) end)
        lu.assertErrorMsgContains('type guard failed', function() s:add(1) end)
        lu.assertErrorMsgContains('type guard failed', function() s:add(true) end)
    end,

    testTypedWithValues = function()
        local s = Set.ofType('string', 'str')
        lu.assertTrue(s:has('str'))
        lu.assertFalse(s:has('something else'))
    end,

    testTypedErrorWhenNotType = function()
        lu.assertErrorMsgContains('type guard failed', function() Set.ofType(1) end)
    end,

    testEnum = function()
        local s = Set.ofEnum(Enum.of("apple", "banana"))
        s:add("apple")
        lu.assertTrue(s:has("apple"))
        lu.assertErrorMsgContains('nil is not a valid value for enum', function() s:add(nil) end)
        lu.assertErrorMsgContains('1 is not a valid value for enum', function() s:add(1) end)
        lu.assertErrorMsgContains('true is not a valid value for enum', function() s:add(true) end)
        lu.assertErrorMsgContains('carrot is not a valid value for enum', function() s:add("carrot") end)
    end,

    testEnumWithValues = function()
        local s = Set.ofEnum(Enum.of("apple", "banana"), "apple")
        lu.assertTrue(s:has("apple"))
        lu.assertFalse(s:has("banana"))
    end,

    testEnumErrorWhenNotEnum = function()
        lu.assertErrorMsgContains('set of enum constructed with non-enum', function() Set.ofEnum("notanenum") end)
    end,

    testSetOfObjectsUsesReferentialUniqueness = function()
        local m1 = SetMember.new(1)
        local m2 = SetMember.new(2)
        local m3 = SetMember.new(2) -- same data, different instance
        local m4 = SetMember.new(3)
        local s = Set.ofType('SetMember'):addAll{m1, m2, m3}

        lu.assertTrue(s:has(m1))
        lu.assertTrue(s:has(m2))
        lu.assertTrue(s:has(m3))
        lu.assertFalse(s:has(m4))
    end,
}
