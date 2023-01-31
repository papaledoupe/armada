import 'util/oo'
local typeGuard <const> = util.oo.typeGuard
local interface <const> = util.oo.interface
import 'util/enum'
local Enum <const> = util.enum

interface "ShipCommand" {
    "getType", -- return ShipCommand.Type
    "execute",

    static = {
        Type = Enum.of('pass', 'steer', 'decelerate', 'accelerate', 'aim'),

        durationSeconds = 2 -- how long, in simulation time, each command takes to execute
    }
}

class "PassCommand" extends "ShipCommand" {
    public {
        getType = function(self) return 'pass' end,
        execute = function(self) end,
    }
}

class "SteerCommand" extends "ShipCommand" {
    public {
        __construct = function(self, args)
            args = args or {}
            self.ship = typeGuard('Ship', args.ship or error('ship required'))
        end,

        getType = function(self)
            return 'steer'
        end,
        
        getTargetBearingRange = function(self)
            return self.ship.movement.bearing - self.ship.stats.maxBearingChange,
                   self.ship.movement.bearing + self.ship.stats.maxBearingChange
        end,

        execute = function(self, args)
            self.ship:setTargetBearing(typeGuard('number', args.target))
        end,
    },
    private {
        ship = null, -- Ship
    }
}

class "AccelerateCommand" extends "ShipCommand" {
    public {
        __construct = function(self, args)
            args = args or {}
            self.ship = typeGuard('Ship', args.ship or error('ship required'))
        end,

        getType = function(self)
            return 'accelerate'
        end,
        
        getTargetVelocityRange = function(self)
            return 
                math.min(self.ship.movement.velocity, self.ship.stats.maxForwardVelocity), 
                math.min(self.ship.movement.velocity + self.ship.stats.maxVelocityChange, self.ship.stats.maxForwardVelocity)
        end,

        execute = function(self, args)
            self.ship:setTargetVelocity(typeGuard('number', args.target))
        end,
    },
    private {
        ship = null, -- Ship
    }
}

class "DecelerateCommand" extends "ShipCommand" {
    public {
        __construct = function(self, args)
            args = args or {}
            self.ship = typeGuard('Ship', args.ship or error('ship required'))
        end,

        getType = function(self)
            return 'decelerate'
        end,
        
        getTargetVelocityRange = function(self)
            return 
                math.max(self.ship.movement.velocity - self.ship.stats.maxVelocityChange, -self.ship.stats.maxBackwardVelocity), 
                math.max(self.ship.movement.velocity, -self.ship.stats.maxBackwardVelocity)
        end,

        execute = function(self, args)
            self.ship:setTargetVelocity(typeGuard('number', args.target))
        end,
    },
    private {
        ship = null, -- Ship
    }
}

class "AimCommand" extends "ShipCommand" {
    public {
        __construct = function(self, args)
            args = args or {}
            self.ship = typeGuard('Ship', args.ship or error('ship required'))
            self.sponsonIdx = typeGuard('number', args.sponsonIdx or error('weaponIdx required'))
            if self.ship:getSponson(self.sponsonIdx) == nil then
                error("no sponson at index " + self.sponsonIdx)
            end
        end,

        getType = function(self)
            return 'aim'
        end,

        getCurrentOrientation = function(self)
            return self.ship:getSponson(self.sponsonIdx).orientation + self.ship.movement.bearing
        end,

        getOrientationRange = function(self)
            return self.ship:getSponsonOrientationRange(self.sponsonIdx)
        end,

        getFrom = function(self)
            return self.ship:getSponsonPosition(self.sponsonIdx)
        end,

        execute = function(self, args)
            self.ship:setSponsonTargetOrientation(self.sponsonIdx, typeGuard('number', args.target))
        end,
    },
    private {
        getter {
            ship = null, -- Ship
            sponsonIdx = 0,
        }
    }
}
