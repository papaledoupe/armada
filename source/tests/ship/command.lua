local lu <const> = import 'lib/luaunit/luaunit'
import 'ship/command'

local function exampleShip(args)
    args = args or {}
    args.stats = args.stats or ShipStats:example()
    return Ship.new(args)
end

TestSteerCommand = {
    testAllowableRange = function()
        local cmd = SteerCommand.new{ship = exampleShip{bearing = 30}}
        local min, max = cmd:getTargetBearingRange()

        lu.assertEquals(min, -60)
        lu.assertEquals(max, 120)
    end,
}

TestAccelerateCommand = {
    testRange = function()
        local ship = exampleShip{velocity = 0}
        local cmd = AccelerateCommand.new{ship = ship}
        local min, max = cmd:getTargetVelocityRange()

        lu.assertEquals(min, 0)
        lu.assertEquals(max, ship.stats.maxVelocityChange)
    end,

    testCannotExceedMaxSpeed = function()
        local v0 = ShipStats:example().maxForwardVelocity - 1
        local ship = exampleShip{velocity = v0}
        local cmd = AccelerateCommand.new{ship = ship}
        local min, max = cmd:getTargetVelocityRange()

        lu.assertEquals(min, v0)
        lu.assertEquals(max, ship.stats.maxForwardVelocity)
    end,
}

TestDecelerateCommand = {
    testRange = function()
        local v0 = 5
        local ship = exampleShip{velocity = v0}
        local cmd = DecelerateCommand.new{ship = ship}
        local min, max = cmd:getTargetVelocityRange()

        lu.assertEquals(min, v0-ship.stats.maxVelocityChange)
        lu.assertEquals(max, v0)
    end,

    testCannotExceedMaxSpeed = function()
        local v0 = 1 - ShipStats:example().maxBackwardVelocity
        local ship = exampleShip{velocity = v0}
        local cmd = DecelerateCommand.new{ship = ship}
        local min, max = cmd:getTargetVelocityRange()

        lu.assertEquals(min, -ship.stats.maxBackwardVelocity)
        lu.assertEquals(max, v0)
    end,
}
