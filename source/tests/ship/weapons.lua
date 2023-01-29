local lu <const> = import 'lib/luaunit/luaunit'
import 'ship/weapons'

TestSponsonWeapon = {

    testFullSpreadWhenNoRotationalFreedom = function()
        local sw = SponsonWeapon.new{orientation = 90, ranges = SponsonWeapon:standardRanges(10, 10), spread = 20}
        local min, max = sw:getFullSpread()

        lu.assertEquals(min, 80)
        lu.assertEquals(max, 100)
    end,

    testInitializeWithOrientationRangeOnly = function()
        local sw = SponsonWeapon.new{minOrientation = 80, maxOrientation = 100, ranges = SponsonWeapon:standardRanges(10, 10), spread = 20}

        lu.assertEquals(sw.orientation, 90)
    end,

    testFullSpreadWhenRotationalFreedom = function()
        local sw = SponsonWeapon.new{
            orientation = 90,
            minOrientation = 70,
            maxOrientation = 110,
            ranges = SponsonWeapon:standardRanges(10, 10),
            spread = 20,
        }
        local min, max = sw:getFullSpread()

        lu.assertEquals(min, 60)
        lu.assertEquals(max, 120)
    end,

    testCurrentSpread = function()
        local sw = SponsonWeapon.new{
            orientation = 90,
            minOrientation = 70,
            maxOrientation = 110,
            ranges = SponsonWeapon:standardRanges(10, 10),
            spread = 20,
        }
        local min, max = sw:getCurrentSpread()

        lu.assertEquals(min, 80)
        lu.assertEquals(max, 100)
    end,

    testSetOrientation = function()
        local sw = SponsonWeapon.new{orientation = 90, ranges = SponsonWeapon:standardRanges(10, 10), spread = 20}
        lu.assertErrorMsgContains('attempted to set orientation to 89 which is outside the range 90 to 90', function()
            sw:setOrientation(89)
        end)

        local sw = SponsonWeapon.new{
            orientation = 90,
            minOrientation = 70,
            maxOrientation = 110,
            ranges = SponsonWeapon:standardRanges(10, 10),
            spread = 20,
        }
        sw:setOrientation(89)
        lu.assertErrorMsgContains('attempted to set orientation to 111 which is outside the range 70 to 110', function()
            sw:setOrientation(111)
        end)
    end,

    testRanges = function()
        local sw = SponsonWeapon.new{orientation = 90, ranges = SponsonWeapon:standardRanges(10, 100), spread = 20}
        
        lu.assertEquals(sw:getMaxRange(), 100)
        lu.assertEquals(sw:getDamageAtRange(101), 0)
        lu.assertEquals(sw:getDamageAtRange(100), 5)
        lu.assertEquals(sw:getDamageAtRange(50), 10)
        lu.assertEquals(sw:getDamageAtRange(0), 10)
        lu.assertEquals(sw:getDamageAtRange(-10), 0)
    end,
}
