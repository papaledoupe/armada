import 'util/oo'
local valueobject <const> = util.oo.valueobject

valueobject "ShipStats" {
    -- unit: meters
    maxForwardVelocity = { type = 'number', validate = function(v) return v >= 0 end },
    maxBackwardVelocity = { type = 'number', validate = function(v) return v >= 0 end },
    
    -- number of commands that have to be given in advance
    inertia = { type = 'number', validate = function(i) return i >= 0 end },
    
    -- % of total velocity range and bearing range that can be changed in a turn
    maneuverability = { type = 'number', validate = function(m) return m >= 0 and m <= 1 end },

    computed = {
        -- actual max velocity change based on maneuverability and max velocity
        maxVelocityChange = function(self)
            local totalRange = self.maxForwardVelocity + self.maxBackwardVelocity
            return totalRange * self.maneuverability
        end,

        -- actual max bearing change based on maneuverability
        maxBearingChange = function(self)
            return 360 * self.maneuverability
        end,
    },

    static = {
        example = function(self)
            return self.new{
                maxForwardVelocity = 30,
                maxBackwardVelocity = 10,
                inertia = 2,
                maneuverability = 1/4,
            }
        end,
    }
}
