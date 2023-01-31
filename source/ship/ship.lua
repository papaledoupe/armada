import 'util/oo'
local typeGuard <const> = util.oo.typeGuard
local typeGuardElements <const> = util.oo.typeGuardElements
import 'util/string'
import 'util/math'
local rotate2D <const> = util.math.rotate2D
local lineAngle <const> = util.math.lineAngle
import 'util/task'
import 'ship/stats'
import 'ship/movement'
import 'ship/command'
import 'ship/weapons'

class "Ship" {
    public {
        __construct = function(self, args)
            args = args or {}

            self.stats = typeGuard('ShipStats', args.stats or error('stats required'))
            self.movement = MovementComponent.new(args)

            self.commands = {}
            self.commandTimer = typeGuard('number', args.commandTimer or -1)

            self.sponsons = typeGuardElements('SponsonWeapon', args.sponsons or {})
        end,

        availableCommands = function(self)
            local cmds = {
                SteerCommand.new{ship = self},
                AccelerateCommand.new{ship = self},
                DecelerateCommand.new{ship = self},
            }
            for i = 1, #self.sponsons do
                table.insert(cmds, AimCommand.new{ship = self, sponsonIdx = i})
            end
            table.insert(cmds, PassCommand.new())
            return cmds
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

        setSponsonTargetOrientation = function(self, idx, target)
            local sponson = self:getSponson(idx) or error('invalid sponson idx '..idx)
            sponson:setTargetOrientation(target - self.movement.bearing)
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
            for _, sponson in ipairs(self.sponsons) do
                sponson:update(dts)
            end

            return false
        end,

        getSponsonsInRangeOf = function(self, x, y)
            local sponsons = {}
            for i, sponson in ipairs(self.sponsons) do
                local sponsonX, sponsonY = self:getSponsonPosition(i)
                local distX = x - sponsonX
                local distY = y - sponsonY

                if math.abs(distX) <= sponson:getMaxRange() 
                    and math.abs(distY) <= sponson:getMaxRange()
                    and math.sqrt(distX*distX + distY*distY) <= sponson:getMaxRange() then
                    -- basic culling checks passed before doing proper maths

                    local arcMin, arcMax = self:getSponsonCurrentSpread(i)
                    local angle = math.deg(lineAngle(distX, distY))
                    if angle >= arcMin and angle <= arcMax then
                        table.insert(sponsons, sponson)
                    end
                end
            end
            return sponsons
        end,

        getSponson = function(self, idx)
            return self.sponsons[idx]
        end,

        getSponsonPosition = function(self, idx)
            local sponson = self.sponsons[idx]
            if sponson == nil then
                return 0, 0
            end
            local rx, ry = rotate2D(sponson.mountPosX, sponson.mountPosY, math.rad(self.movement.bearing))
            return self.movement.x + rx, self.movement.y + ry
        end,

        getSponsonCurrentSpread = function(self, idx)
            local sponson = self.sponsons[idx]
            if sponson == nil then
                return 0, 0
            end
            local min, max = sponson:getCurrentSpread()
            return min + self.movement.bearing, max + self.movement.bearing
        end,

        getSponsonOrientationRange = function(self, idx)
            local sponson = self.sponsons[idx]
            if sponson == nil then
                return 0, 0
            end
            return sponson.minOrientation + self.movement.bearing, sponson.maxOrientation + self.movement.bearing
        end,
    },
    private {
        getter {
            stats = null, -- ShipStats
            movement = null, -- MovementComponent
            commands = {}, -- []ShipCommand
            commandTimer = 0, -- simulation-seconds since last command was executed
            sponsons = {}, -- []SponsonWeapon
        },
    }
}
