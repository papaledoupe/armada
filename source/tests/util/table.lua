local lu <const> = import 'lib/luaunit/luaunit'
import 'util/table'

TestTableUtils = {

    testReverse = function()
        lu.assertEquals(util.table.reversed{1, 2, 3}, {3, 2, 1})
    end,

    testJoinValues = function()
        lu.assertEquals(util.table.joinValues({}, '+'), '')
        lu.assertEquals(util.table.joinValues({1}, '+'), '1')
        lu.assertEquals(util.table.joinValues({1, '2', true}, '+'), '1+2+true')
        lu.assertEquals(util.table.joinValues({1, '2', true}, ', '), '1, 2, true')
        lu.assertEquals(util.table.joinValues({'', ''}, ', '), ', ')
    end,

    testHasValue = function()
        local arr = {1, 2, 4}
        lu.assertTrue(util.table.hasValue(arr, 1))
        lu.assertTrue(util.table.hasValue(arr, 2))
        lu.assertFalse(util.table.hasValue(arr, 3))
        lu.assertTrue(util.table.hasValue(arr, 4))
        
        local kv = {a = 1, b = 2, c = 4}
        lu.assertTrue(util.table.hasValue(arr, 1))
        lu.assertTrue(util.table.hasValue(arr, 2))
        lu.assertFalse(util.table.hasValue(arr, 3))
        lu.assertTrue(util.table.hasValue(arr, 4))
    end,

    testReadonly = function()
        local ro = util.table.readonly{3, 4}
        lu.assertEquals(ro[1], 3)
        lu.assertEquals(ro[2], 4)
        lu.assertEquals(ro[3], nil)

        lu.assertEquals(#ro, 2)
        lu.assertErrorMsgContains('attempt to update a readonly table', function() table.insert(ro, 5) end)
        lu.assertEquals(ro[3], nil)
        lu.assertEquals(#ro, 2)

        lu.assertErrorMsgContains('attempt to update a readonly table', function() table.remove(ro) end)
        lu.assertEquals(#ro, 2)
    end,

    testReadonlyTableIterable_pairs = function()
        local ro = util.table.readonly{a = 3,  b = 4}
        local out = {}
        for k, v in pairs(ro) do
            out[k] = v
        end
        lu.assertEquals(out, {a = 3, b = 4})
    end,

    testReadonlyTableIterable_ipairs = function()
        local ro = util.table.readonly{3, 4}
        local out = {}
        for i, v in ipairs(ro) do
            out[i] = v
        end
        lu.assertEquals(out, {3, 4})
    end,

    testShuffle = function()
        local mockRandom = function(i) return math.floor(i/2) end
        local table = {'a', 'b', 'c', 'd', 'e'}

        util.table.shuffle(table, mockRandom)

        lu.assertEquals(table, {'a', 'd', 'b', 'e', 'c'})
    end,

}
