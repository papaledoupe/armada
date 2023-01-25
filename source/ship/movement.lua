import 'util/oo'
local typeGuard <const> = util.oo.typeGuard

class "MovementComponent" {
    public {
        __construct = function(self, args)
            self.x = typeGuard('number', args.x or 0)
            self.y = typeGuard('number', args.y or 0)
            
            self.velocity = typeGuard('number', args.velocity or 0)
            self.targetVelocity = typeGuard('number', args.targetVelocity or self.velocity)
            self.startVelocity = self.velocity

            self.bearing = typeGuard('number', args.bearing or 0)
            self.targetBearing = typeGuard('number', args.targetBearing or self.bearing)
            self.startBearing = self.bearing
        end,

        copy = function(self)
            return MovementComponent.new{
                x = self.x,
                y = self.y,
                velocity = self.velocity,
                targetVelocity = self.targetVelocity,
                bearing = self.bearing,
                targetBearing = self.targetBearing,
            }
        end,

        pos = function(self)
            return self.x, self.y
        end,

        -- dts is simulation time
        update = function(self, dts)
            -- performing acceleration and rotation halfway through the movement interpolates the motion giving a more accurate result
            -- otherwise, increasing the size of dts can change the final position substantially
            self:moveForward(self.velocity * dts / 2)
            if self.targetVelocity ~= self.velocity then
                local dv = dts * ((self.targetVelocity - self.startVelocity) / ShipCommand.durationSeconds)
                self.velocity = self.velocity + dv
                if (dv > 0 and self.velocity > self.targetVelocity) or (dv < 0 and self.velocity < self.targetVelocity) then
                    self.velocity = self.targetVelocity -- prevent overshot
                end
            end
            if self.targetBearing ~= self.bearing then
                local db = dts * ((self.targetBearing - self.startBearing) / ShipCommand.durationSeconds)
                self.bearing = self.bearing + db
                if (db > 0 and self.bearing > self.targetBearing) or (db < 0 and self.bearing < self.targetBearing) then
                    self.bearing = self.targetBearing -- prevent overshot
                end
            end
            self:moveForward(self.velocity * dts / 2)
        end,

        setTargetVelocity = function(self, v)
            self.targetVelocity = typeGuard('number', v)
            self.startVelocity = self.velocity
        end,

        setTargetBearing = function(self, b)
            self.targetBearing = typeGuard('number', b)
            self.startBearing = self.bearing
        end,

        getCompassBearing = function(self)
            return self.bearing % 360
        end,
    },
    private {
        getter {
            x = 0,
            y = 0,
            velocity = 0,
            targetVelocity = 0,
            bearing = 0,
            targetBearing = 0,
        },

        startVelocity = 0, -- velocity when targetVelocity was last set.
        startBearing = 0, -- bearing when targetBearing was last set

        moveForward = function(self, d)
            typeGuard('number', d or 0)
            self.x = self.x + d * math.cos(math.rad(self.bearing - 90))
            self.y = self.y + d * math.sin(math.rad(self.bearing - 90))
        end,
    },
}