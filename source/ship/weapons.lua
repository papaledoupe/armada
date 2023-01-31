import 'util/oo'
local typeGuard <const> = util.oo.typeGuard
local typeGuardKeysValues <const> = util.oo.typeGuardKeysValues
import 'util/memo'
local memo <const> = util.memo

-- a weapon with rotational freedom
-- "range" and "spread" define a sector shaped target area
-- "orientation" is the angle (deg) of the line bisecting the sector
-- (a weapon with spread 60 and min orientiation 80 and max orientation 100 can therefore fire between 50 and 130 deg)
-- "mount pos" is relative position of weapon on the thing it's mounted on
class "SponsonWeapon" {
    public {
        static {
            standardRanges = function(self, maxDamage, maxRange)
                return {
                    [math.ceil(maxRange * .75)] = maxDamage,
                    [maxRange] = math.ceil(maxDamage/2),
                }
            end,
        },

        __construct = function(self, args)
            args = args or {}

            local orientation = 0
            if args.orientation == nil then
                self.minOrientation = typeGuard('number', args.minOrientation or error('minOrientation required when orientation not given'))
                self.maxOrientation = typeGuard('number', args.maxOrientation or error('maxOrientation required when orientation not given'))
                orientation = (self.maxOrientation + self.minOrientation) / 2
            else
                orientation = typeGuard('number', args.orientation)
                self.minOrientation = typeGuard('number', args.minOrientation or orientation)
                self.maxOrientation = typeGuard('number', args.maxOrientation or orientation)                
            end
            self:setOrientation(orientation)
            
            self.ranges = typeGuardKeysValues('number', 'number', args.ranges or error('ranges required'))
            self.spread = typeGuard('number', args.spread or error('spread required'))
            self.mountPosX = typeGuard('number', args.mountPosX or 0)
            self.mountPosY = typeGuard('number', args.mountPosY or 0)
        end,

        getFullSpread = memo(function(self)
            return self.minOrientation - self.spread/2, self.maxOrientation + self.spread/2
        end),

        getCurrentSpread = memo(function(self)
            return self.orientation - self.spread/2, self.orientation + self.spread/2
        end),

        setOrientation = function(self, o)
            typeGuard('number', o)
            if o < self.minOrientation or o > self.maxOrientation then
                error("attempted to set orientation to ${1} which is outside the range ${2} to ${3}" % {
                    o, self.minOrientation, self.maxOrientation
                })
            end
            self.orientation = o
            self.targetOrientation = o
            self.startOrientation = o
        end,

        getMaxRange = memo(function(self)
            local max = 0
            for rng, dmg in pairs(self.ranges) do
                max = math.max(max, rng)
            end
            return max
        end),

        getDamageAtRange = function(self, r)
            typeGuard('number', r)
            if r < 0 then
                return 0
            end
            local max = 0
            for rng, dmg in pairs(self.ranges) do
                if r <= rng then
                    max = math.max(max, dmg)
                end
            end
            return max
        end,

        setTargetOrientation = function(self, o)
            typeGuard('number', o)
            self.targetOrientation = o
            self.startOrientation = self.orientation
        end,

        update = function(self, dts)
            if self.targetOrientation ~= self.orientation then
                local db = dts * ((self.targetOrientation - self.startOrientation) / ShipCommand.durationSeconds)
                self.orientation = self.orientation + db
                if (db > 0 and self.orientation > self.targetOrientation) or (db < 0 and self.orientation < self.targetOrientation) then
                    self.orientation = self.targetOrientation -- prevent overshot
                end
            end
        end,
    },
    private {
        getter {
            orientation = 0,
            targetOrientation = 0,
            ranges = {},
            spread = 0,
            mountPosX = 0,
            mountPosY = 0,
            minOrientation = 0,
            maxOrientation = 0,
        },
        startOrientation = 0, -- orientation at time new targetOrientation was set
    }
}
