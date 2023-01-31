local lu <const> = import 'lib/luaunit/luaunit'
import 'ship/ship'
import 'tests/support/class_mock'
local classMock <const> = testSupport.classMock

local function exampleShip(args)
    args = args or {}
    args.stats = args.stats or ShipStats:example()
    return Ship.new(args)
end

TestShip = {

    testNeedsCommandUntilInertiaMet = function()
        local s = exampleShip()
        lu.assertTrue(s:needsCommand())
        
        s:enqueueCommand(PassCommand.new())
        lu.assertTrue(s:needsCommand())
        
        s:enqueueCommand(PassCommand.new())
        lu.assertFalse(s:needsCommand())

        lu.assertErrorMsgContains('already have maximum commands', function() 
            s:enqueueCommand(PassCommand.new()) 
        end)

        s:update(ShipCommand.durationSeconds + 1)
        s:update(0, {})
        lu.assertTrue(s:needsCommand())

        s:enqueueCommand(PassCommand.new())
        lu.assertFalse(s:needsCommand())
    end,

    testSetTargetVelocityCannotExceedMaxForward = function()
        local s = exampleShip{velocity = 30}
        lu.assertErrorMsgContains('31 exceeds max forward velocity of 30', function() 
            s:setTargetVelocity(31)
        end)
    end,

    testSetTargetVelocityCannotExceedMaxBackward = function()
        local s = exampleShip{velocity = -10}
        lu.assertErrorMsgContains('-11 exceeds max backward velocity of 10', function() 
            s:setTargetVelocity(-11)
        end)
    end,

    testSetTargetVelocityCannotExceedManeuverability = function()
        local s = exampleShip{velocity = 10}
        lu.assertErrorMsgContains('setting target velocity to 25 changes it by 15 which exceeds the max velocity change of 10', function() 
            s:setTargetVelocity(25)
        end)

        s = exampleShip{velocity = 5}
        lu.assertErrorMsgContains('setting target velocity to -6 changes it by 11 which exceeds the max velocity change of 10', function() 
            s:setTargetVelocity(-6)
        end)
    end,

    testSetTargetVelocityWithinLimits = function()
        exampleShip{velocity = 0}:setTargetVelocity(5)
        exampleShip{velocity = 20}:setTargetVelocity(30)
        exampleShip{velocity = 0}:setTargetVelocity(-10)
        exampleShip{velocity = 5}:setTargetVelocity(-5)
    end,

    testSetTargetBearingCannotExceedManeuverability = function()
        local s = exampleShip{bearing = 10}
        lu.assertErrorMsgContains('setting target bearing to 110 changes it by 100 which exceeds the max bearing change of 90', function() 
            s:setTargetBearing(110)
        end)
        local s = exampleShip{bearing = 10}
        lu.assertErrorMsgContains('setting target bearing to -90 changes it by 100 which exceeds the max bearing change of 90', function() 
            s:setTargetBearing(-90)
        end)
    end,

    testSetTargetBearingWithinLimits = function()
        exampleShip{bearing = 0}:setTargetBearing(90)
        exampleShip{bearing = 0}:setTargetBearing(-90) -- should be same as above
        exampleShip{bearing = 45}:setTargetBearing(-40)
    end,

    testUpdatePositionAndBearing = function()
        local ship = exampleShip{bearing = 0, velocity = 10, commandTimer = 0}
        ship:setTargetBearing(90)

        lu.assertEquals(ship.movement.x, 0)
        lu.assertEquals(ship.movement.y, 0)
        lu.assertEquals(ship.movement.bearing, 0)

        local n = 10
        for i = 1, n do
            lu.assertFalse(ship:update(ShipCommand.durationSeconds / n))
        end
        -- rotation of 90 deg travelling <ShipCommand.durationSeconds>*<velocity> meters gives radius of (2*velocity*durationSeconds)/pi
        -- note that as movement is not smooth, but a series of straight lines of length <dts>, accuracy is lost as <dts> gets larger.
        lu.assertEquals(math.floor(ship.movement.x), math.floor((2*10*ShipCommand.durationSeconds)/math.pi))
        lu.assertEquals(math.ceil(ship.movement.y), math.ceil(-(2*10*ShipCommand.durationSeconds)/math.pi))
    end,

    testUpdatePositionAndBearingWhenBearingPassesZero = function()
        local ship = exampleShip{bearing = 45, velocity = 10, commandTimer = 0}
        ship:setTargetBearing(-45)

        lu.assertEquals(ship.movement.x, 0)
        lu.assertEquals(ship.movement.y, 0)
        lu.assertEquals(ship.movement.bearing, 45)

        local n = 10
        for i = 1, n do
            lu.assertFalse(ship:update(ShipCommand.durationSeconds / n))
        end
        -- rotation of 90 deg CCW travelling <ShipCommand.durationSeconds>*<velocity> meters gives radius of (2*velocity*durationSeconds)/pi
        -- y movement is along a chord. based on radius, chord length is sqrt(2)*r
        lu.assertEquals(math.floor(ship.movement.x), 0)
        lu.assertEquals(math.floor(ship.movement.y), math.ceil(-1 * math.sqrt(2) * (2*10*ShipCommand.durationSeconds)/math.pi))
    end,

    testAcceleration = function()
        local ship = exampleShip{bearing = 90, velocity = 10, commandTimer = 0}
        ship:setTargetVelocity(20)

        local n = 10
        for i = 1, n do
            lu.assertFalse(ship:update(ShipCommand.durationSeconds / n))
        end
        lu.assertEquals(math.floor(ship.movement.velocity), 20)
        lu.assertEquals(ship.movement.y, 0)
        lu.assertEquals(math.floor(ship.movement.x), 15*ShipCommand.durationSeconds)
    end,

    testProjectMovementMatchesActualMovement = function()
        local ship = exampleShip{bearing = 90, velocity = 10, commandTimer = 0}
        ship:setTargetVelocity(20)
        ship:setTargetBearing(180)

        local n = 10
        local proj = ship:projectMovement{duration = ShipCommand.durationSeconds, steps = n}
        lu.assertEquals(#proj, n)

        for i = 1, n do
            lu.assertFalse(ship:update(ShipCommand.durationSeconds / n))
            lu.assertEquals(ship.movement.bearing, proj[i].bearing)
            lu.assertEquals(ship.movement.x, proj[i].x)
            lu.assertEquals(ship.movement.y, proj[i].y)
        end
    end,

    testGetSponsonPositionIsTransformedByShipPosition = function()
        local ship = exampleShip{
            sponsons = {classMock('SponsonWeapon', {mountPosX = 10, mountPosY = -10})},
            x = 100,
            y = 100,
            bearing = 0,
        }

        local x, y = ship:getSponsonPosition(1)
        lu.assertEquals(x, 110)
        lu.assertEquals(y, 90)
    end,

    testGetSponsonPositionIsTransformedByShipBearing = function()
        local ship = exampleShip{
            sponsons = {classMock('SponsonWeapon', {mountPosX = 10, mountPosY = -10})},
            x = 0,
            y = 0,
            bearing = 90,
        }

        local x, y = ship:getSponsonPosition(1)
        lu.assertEquals(x, 10)
        lu.assertEquals(y, 10)
    end,

    testGetSponsonsInRangeOf = function()
        local range = SponsonWeapon:standardRanges(10, 10)
        local fwdSponson = SponsonWeapon.new{orientation = 0,   ranges = range, spread = 90}
        local aftSponson = SponsonWeapon.new{orientation = 180, ranges = range, spread = 90}
        local ship = exampleShip{
            sponsons = {fwdSponson, aftSponson},
            x = 50,
            y = 50,
            bearing = 0,
        }

        lu.assertEquals(ship:getSponsonsInRangeOf(0, 0), {})
        lu.assertEquals(ship:getSponsonsInRangeOf(60, 60), {})
        lu.assertEquals(ship:getSponsonsInRangeOf(40, 40), {})
        lu.assertEquals(ship:getSponsonsInRangeOf(50, 40), {fwdSponson})
        lu.assertEquals(ship:getSponsonsInRangeOf(50, 45), {fwdSponson})
        lu.assertEquals(ship:getSponsonsInRangeOf(55, 50), {})
        lu.assertEquals(ship:getSponsonsInRangeOf(50, 60), {aftSponson})
        lu.assertEquals(ship:getSponsonsInRangeOf(50, 55), {aftSponson})
        lu.assertEquals(ship:getSponsonsInRangeOf(45, 50), {})
    end,

    testSetSponsonTargetOrientation = function()
        local sponsonArg = nil
        local ship = exampleShip{
            sponsons = {classMock('SponsonWeapon', {setTargetOrientation = function(self, tgt) sponsonArg = tgt end})},
            x = 0,
            y = 0,
            bearing = 90,
        }

        lu.assertErrorMsgContains('invalid sponson idx 0', function() ship:setSponsonTargetOrientation(0, 123) end)
        lu.assertErrorMsgContains('invalid sponson idx 2', function() ship:setSponsonTargetOrientation(2, 123) end)

        ship:setSponsonTargetOrientation(1, 123)
        lu.assertEquals(123 - 90, sponsonArg) -- transforms to local coords, i.e., subtracts shop orientation
    end,
}
