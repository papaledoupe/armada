import 'util/oo'
local typeGuard <const> = util.oo.typeGuard
local interface <const> = util.oo.interface
local valueobject <const> = util.oo.valueobject
import 'util/enum'
local Enum <const> = util.enum
import 'util/string'
import 'util/task'

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

interface "ShipCommand" {
    "getType", -- return ShipCommand.Type
    "execute",

    static = {
        Type = Enum.of('pass', 'steer', 'decelerate', 'accelerate'),

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

class "Ship" {
    public {
        __construct = function(self, args)
            args = args or {}

            self.stats = typeGuard('ShipStats', args.stats or error('stats required'))
            self.movement = MovementComponent.new(args)

            self.commands = {}
            self.commandTimer = typeGuard('number', args.commandTimer or -1)
        end,

        availableCommands = function(self)
            return {
                AccelerateCommand.new{ship = self},
                DecelerateCommand.new{ship = self},
                SteerCommand.new{ship = self},
                PassCommand.new(),
            }
        end,

        needsCommand = function(self)
            return #self.commands < self.stats.inertia
        end,

        enqueueCommand = function(self, command)
            typeGuard('ShipCommand', command)
            if #self.commands == self.stats.inertia then
                error('already have maximum commands')
            end
            table.insert(self.commands, command)
        end,

        currentCommand = function(self)
            return self.commands[1]
        end,

        setTargetVelocity = function(self, v)
            typeGuard('number', v)
            local dv = math.abs(v - self.movement.velocity)
            if dv > self.stats.maxVelocityChange then
                error('setting target velocity to ${1} changes it by ${2} which exceeds the max velocity change of ${3}' % {
                    v, dv, self.stats.maxVelocityChange
                })
            end
            if v > 0 and v > self.stats.maxForwardVelocity then
                error('${1} exceeds max forward velocity of ${2}' % {v, self.stats.maxForwardVelocity})
            end
            if v < 0 and math.abs(v) > self.stats.maxBackwardVelocity then
                error('${1} exceeds max backward velocity of ${2}' % {v, self.stats.maxBackwardVelocity})
            end
            self.movement:setTargetVelocity(v)
        end,

        setTargetBearing = function(self, b)
            local db = math.abs(b - self.movement.bearing)
            if db > self.stats.maxBearingChange then
                error('setting target bearing to ${1} changes it by ${2} which exceeds the max bearing change of ${3}' % {
                    b, db, self.stats.maxBearingChange
                })
            end
            self.movement:setTargetBearing(b)
        end,

        -- provide a array of {x, y, bearing} positions representing motion on current trajectory, with the requested number of steps
        projectMovement = function(self, args)
            args = args or {}
            local duration = typeGuard('number', args.duration or ShipCommand.durationSeconds)
            local steps = typeGuard('number', args.steps or 50)

            local m = self.movement:copy()
            if type(args.targetBearing) == 'number' then
                m:setTargetBearing(args.targetBearing)
            end
            if type(args.targetVelocity) == 'number' then
                m:setTargetVelocity(args.targetVelocity)
            end

            local dt = duration/steps
            local path = {}
            for step = 1, steps do
                m:update(dt)
                table.insert(path, {x = m.x, y = m.y, bearing = m.bearing})
            end
            return path
        end,

        -- dts is simulation delta time seconds, which may be zero if not running, or sped up / slowed down relative to real time
        -- if new command is required to be executed, returns true
        -- if command args are passed, next command is executed using these arguments
        update = function(self, dts, commandArgs)
            if commandArgs ~= nil then
                local command = table.remove(self.commands, 1)
                if command ~= nil then
                    command:execute(typeGuard('table', commandArgs))
                end
            end

            if dts == 0 then
                return false
            end

            if self.commandTimer == -1 then
                self.commandTimer = dts
                return true
            end

            self.commandTimer = self.commandTimer + dts
            if self.commandTimer > ShipCommand.durationSeconds then
                self.commandTimer = -1
                return true
            end

            self.movement:update(dts)

            return false
        end,
    },
    private {
        getter {
            stats = null, -- ShipStats
            movement = null, -- MovementComponent
            commands = {}, -- []ShipCommand
            commandTimer = 0, -- simulation-seconds since last command was executed
        },
    }
}
