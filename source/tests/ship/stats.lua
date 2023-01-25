local lu <const> = import 'lib/luaunit/luaunit'
import 'ship/stats'

TestShipStats = {

    testMaxVelocityChange = function()
        lu.assertEquals(ShipStats:example().maxVelocityChange, 10)
    end,

    testMaxBearingChange = function()
        lu.assertEquals(ShipStats:example().maxBearingChange, 360/4)
    end,
}