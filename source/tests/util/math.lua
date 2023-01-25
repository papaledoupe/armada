local lu <const> = import 'lib/luaunit/luaunit'
import 'util/math'

TestMathUtils = {

    testIsNaN = function()
        lu.assertTrue(util.math.isNaN(0/0))
        lu.assertFalse(util.math.isNaN(1))
        lu.assertFalse(util.math.isNaN(false))
        lu.assertFalse(util.math.isNaN("str"))
        lu.assertFalse(util.math.isNaN("nan"))
    end,

    testClamp = function()
        lu.assertEquals(util.math.clamp(0, 1, 3), 1)
        lu.assertEquals(util.math.clamp(1, 1, 3), 1)
        lu.assertEquals(util.math.clamp(2, 1, 3), 2)
        lu.assertEquals(util.math.clamp(3, 1, 3), 3)
        lu.assertEquals(util.math.clamp(4, 1, 3), 3)
    end,

    testCycle = function()
        lu.assertEquals(util.math.cycle(0, 1, 3), 3)
        lu.assertEquals(util.math.cycle(1, 1, 3), 1)
        lu.assertEquals(util.math.cycle(2, 1, 3), 2)
        lu.assertEquals(util.math.cycle(3, 1, 3), 3)
        lu.assertEquals(util.math.cycle(4, 1, 3), 1)
    end,

    testNtoZAndZtoN = function()
        for i = -100,100 do
            lu.assertEquals(util.math.NtoZ(util.math.ZtoN(i)), i)
        end
        for i = 0,100 do
            lu.assertEquals(util.math.ZtoN(util.math.NtoZ(i)), i)
        end
        lu.assertErrorMsgContains('-5 is not a natural number', function()
            util.math.NtoZ(-5)
        end)
        lu.assertErrorMsgContains('banana is not a natural number', function()
            util.math.NtoZ('banana')
        end)
        -- overflow testing
        lu.assertErrorMsgContains(util.math.MaxInteger..' is too large for ZtoN', function()
            util.math.ZtoN(util.math.MaxInteger)
        end)
        lu.assertTrue(util.math.ZtoN(util.math.MaxInteger/4) > util.math.MaxInteger/4)
        lu.assertEquals(util.math.ZtoN(util.math.NtoZ(util.math.MaxInteger/2)), util.math.MaxInteger/2)
    end,

    testPairProducesUniqueUnpairableValues = function()
        local ks = {}
        for i = -100, 100 do
            for j = -100, 100 do
                local k = util.math.pair(i, j)
                lu.assertNil(ks[k])
                ks[k] = true
                local i2, j2 = util.math.unpair(k)
                lu.assertEquals(i2, i)
                lu.assertEquals(j2, j)
            end
        end
    end,

    testPairRepeatable = function()
        lu.assertEquals(util.math.pair(4, 5), util.math.pair(4, 5))
        lu.assertNotEquals(util.math.pair(4, 5), util.math.pair(5, 4))
        lu.assertNotEquals(util.math.pair(4, 5), util.math.pair(-4, -5))
    end,

    testRound = function()
        lu.assertEquals(util.math.round(1), 1)
        lu.assertEquals(util.math.round(1.1), 1)
        lu.assertEquals(util.math.round(1.4), 1)
        lu.assertEquals(util.math.round(1.5 - 1e-10), 1)
        lu.assertEquals(util.math.round(1.5), 2)
        lu.assertEquals(util.math.round(0.9), 1)
        lu.assertEquals(util.math.round(0.5), 1)
        lu.assertEquals(util.math.round(0.5 - 1e-10), 0)
    end,

    testRotate2d = function()
        -- awkward because luaunit has no "approximately equals"
        -- so just using silly big number + rounding

        local x, y = util.math.rotate2D(1e10, 1e10, math.pi)
        lu.assertEquals(util.math.round(x), -1e10)
        lu.assertEquals(util.math.round(y), -1e10)

        x, y = util.math.rotate2D(1e10, 1e10, math.pi/2)
        lu.assertEquals(util.math.round(x), -1e10)
        lu.assertEquals(util.math.round(y), 1e10)

        x, y = util.math.rotate2D(1e10, 1e10, 3*math.pi/2)
        lu.assertEquals(util.math.round(x), 1e10)
        lu.assertEquals(util.math.round(y), -1e10)

        x, y = util.math.rotate2D(1e10, 3e10, math.pi)
        lu.assertEquals(util.math.round(x), -1e10)
        lu.assertEquals(util.math.round(y), -3e10)
    end,
}
