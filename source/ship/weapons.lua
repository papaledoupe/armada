import 'util/oo'
local typeGuard <const> = util.oo.typeGuard

-- a weapon with rotational freedom
-- "range" and "spread" define a sector shaped target area
-- "orientation" is the angle (deg) of the line bisecting the sector
-- (a weapon with spread 60 and min orientiation 80 and max orientation 100 can therefore fire between 50 and 130 deg)
-- "mount pos" is relative position of weapon on the thing it's mounted on
class "SponsonWeapon" {
    public {
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
            
            self.range = typeGuard('number', args.range or error('range required'))
            self.spread = typeGuard('number', args.spread or error('spread required'))
            self.mountPosX = typeGuard('number', args.mountPosX or 0)
            self.mountPosY = typeGuard('number', args.mountPosY or 0)
        end,

        getFullSpread = function(self)
            return self.minOrientation - self.spread/2, self.maxOrientation + self.spread/2
        end,

        setOrientation = function(self, o)
            typeGuard('number', o)
            if o < self.minOrientation or o > self.maxOrientation then
                error("attempted to set orientation to ${1} which is outside the range ${2} to ${3}" % {
                    o, self.minOrientation, self.maxOrientation
                })
            end
            self.orientation = o
        end,
    },
    private {
        getter {
            orientation = 0,
            range = 0,
            spread = 0,
            mountPosX = 0,
            mountPosY = 0,
            minOrientation = 0,
            maxOrientation = 0,
        },
    }
}
