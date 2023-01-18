local lu <const> = import 'lib/luaunit/luaunit'
import 'util/enum'
local Enum <const> = util.enum

TestEnum = {

    testHasValues = function()
        local e = Enum.of("north", "east", "south", "west")
        lu.assertTrue(e:has("north"))
        lu.assertTrue(e:has("west"))
        lu.assertFalse(e:has("southeast"))
    end,

    testGuardValues = function()
        local e = Enum.of("north", "east", "south", "west")
        lu.assertEquals(e:guard("north"), "north")
        lu.assertEquals(e:guard("west"), "west")
        lu.assertErrorMsgContains("southeast is not a valid value for enum", function() e:guard("southeast") end)
    end,

    testUnion = function()
        local arrows = Enum.of("up", "down")
        local chars = Enum.of("a", "b")
        local modifiers = Enum.of("shift", "cmd")
        local keys = Enum.union(arrows, chars, modifiers)

        lu.assertTrue(keys:has("up"))
        lu.assertTrue(keys:has("shift"))
        lu.assertTrue(keys:has("b"))
        lu.assertFalse(keys:has("c"))
    end,

    testEnumCannotHaveNoValues = function()
        lu.assertErrorMsgContains("empty enum not allowed", function() Enum.of() end)
    end,

    testEnumGetValues = function()
        local values = Enum.of('a', 'b', 'c')
        lu.assertEquals(#values:getValues(), 3)
        lu.assertTableContains(values:getValues(), 'a')
        lu.assertTableContains(values:getValues(), 'b')
        lu.assertTableContains(values:getValues(), 'c')
    end,

}
