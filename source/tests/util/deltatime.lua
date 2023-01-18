local lu <const> = import 'lib/luaunit/luaunit'
import 'util/deltatime'

TestDeltaTime = {

    setUp = function()
        DeltaTime.reset()
    end,

    testWorksWithManualTimeOutsideOfPlaydate = function()
        DeltaTime.update(0)
        lu.assertEquals(0, DeltaTime.getMillis())
        DeltaTime.update(10)
        lu.assertEquals(DeltaTime.getMillis(), 10)
        lu.assertEquals(DeltaTime.getMillis(), 10)
        DeltaTime.update(13)
        lu.assertEquals(DeltaTime.getMillis(), 3)
        lu.assertEquals(DeltaTime.getSeconds(), 0.003)
    end,

    testUpdateWithoutManualTimeDoesNotWorkOutsidePlaydate = function()
        lu.assertError(function() DeltaTime.update() end)
    end,

    testThrottled = function()
        local calls = {}
        local throttled = DeltaTime.throttled({windowMillis = 10}, function(arg1, arg2)
            table.insert(calls, {arg1, arg2})
        end)

        DeltaTime.update(0)
        throttled(1, 2)
        lu.assertEquals(#calls, 1)
        lu.assertEquals(calls, {{1, 2}})

        DeltaTime.update(9)
        throttled(2, 3)
        lu.assertEquals(#calls, 1)
        lu.assertEquals(calls, {{1, 2}})

        DeltaTime.update(13)
        throttled(3, 4)
        lu.assertEquals(#calls, 2)
        lu.assertEquals(calls, {{1, 2}, {3, 4}})

        DeltaTime.update(20)
        throttled(4, 5)
        lu.assertEquals(#calls, 2)
        lu.assertEquals(calls, {{1, 2}, {3, 4}})

        DeltaTime.update(23)
        throttled(5, 6)
        lu.assertEquals(#calls, 3)
        lu.assertEquals(calls, {{1, 2}, {3, 4}, {5, 6}})
    end,
}