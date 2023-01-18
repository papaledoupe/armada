local lu <const> = import 'lib/luaunit/luaunit'
import 'util/memo'

TestMemo = {

    testMemoOnNoArgsFunctionCachesForever = function()
        local calls = 0
        local memoized = util.memo(function()
            calls = calls + 1
            return calls
        end)

        lu.assertEquals(memoized(), 1)
        lu.assertEquals(calls, 1)
        lu.assertEquals(memoized(), 1)
        lu.assertEquals(calls, 1)
        lu.assertEquals(memoized(), 1)
        lu.assertEquals(calls, 1)
    end,

    testMemoFunctionCachesLastValueForSameArguments = function()
        local calls = 0
        local memoized = util.memo(function(a1, a2)
            calls = calls + 1
            return a1 * a2
        end)

        lu.assertEquals(memoized(2, 3), 6)
        lu.assertEquals(calls, 1)

        lu.assertEquals(memoized(2, 3), 6)
        lu.assertEquals(calls, 1)

        lu.assertEquals(memoized(3, 2), 6)
        lu.assertEquals(calls, 2)

        lu.assertEquals(memoized(3, 3), 9)
        lu.assertEquals(calls, 3)
        
        lu.assertEquals(memoized(3, 3), 9)
        lu.assertEquals(calls, 3)
        
        lu.assertEquals(memoized(3, 3, 1), 9)
        lu.assertEquals(calls, 4)
    end,

    testMemoDoesNotWorkForValuesWithoutTrivialEquality = function()
        local calls = 0
        local memoized = util.memo(function(tbl)
            calls = calls + 1
            return tbl.a * tbl.b
        end)

        lu.assertEquals(memoized{a = 2, b = 3}, 6)
        lu.assertEquals(calls, 1)

        lu.assertEquals(memoized{a = 2, b = 3}, 6)
        lu.assertEquals(calls, 2)
    end,

    testMemoWithCustomKeyExtractor = function()
        local calls = 0
        local memoized = util.memo(
            function(tbl, add)
                calls = calls + 1
                return (tbl.a * tbl.b) + add
            end,
            {extractKeys = function(tbl, add)
                return {tbl.a, tbl.b, add}
            end}
        )

        lu.assertEquals(memoized({a = 2, b = 3}, 1), 7)
        lu.assertEquals(calls, 1)

        lu.assertEquals(memoized({a = 2, b = 3}, 1), 7)
        lu.assertEquals(calls, 1)

        lu.assertEquals(memoized({a = 4, b = 3}, 1), 13)
        lu.assertEquals(calls, 2)

        lu.assertEquals(memoized({a = 4, b = 3}, 3), 15)
        lu.assertEquals(calls, 3)
    end,

}
