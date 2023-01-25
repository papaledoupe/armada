import "CoreLibs/graphics"
local geom <const> = playdate.geometry
local v <const> = geom.vector2D.new
local gfx <const> = playdate.graphics
local Timer <const> = playdate.timer
import 'ui/lifecycle'
import 'util/fsm'
import 'util/set'
local Set <const> = util.set
import 'util/deltatime'
import 'util/math'
local cycle <const> = util.math.cycle
local clamp <const> = util.math.clamp
import 'util/memo'
local memo <const> = util.memo
import 'util/oo'
local typeGuard <const> = util.oo.typeGuard
local typeGuardElements <const> = util.oo.typeGuardElements
local instanceOf <const> = util.oo.instanceOf

local playdateScreenW <const> = 400
local playdateScreenH <const> = 240

-- time taken (ms) to move camera from one point or another (independent of distance)
local cameraMoveTime <const> = 400

local bearingChangePerCrankDegree <const> = 0.5

class "WorldUI" extends "UILifecycle" {
    public {
        __construct = function(self, args)
            args = args or {}
            self.controller = typeGuard('UIController', args.controller or error('controller required'))
            self.game = typeGuard('GameState', args.game or error('game required'))
            
            local commandWidget = CommandWidget.new()
            self.commandWidget = commandWidget

            self:setActiveShip(args.activeShipIdx or 1)

            self.taskQueue = TaskQueue.new()

            local game = self.game
            local controller = self.controller
            self.fsm = FiniteStateMachine.new{
                --log = true,
                start = 'CHOOSE_COMMAND',
                transitions = {
                    StateTransition.new{
                        from = 'CHOOSE_COMMAND',
                        event = 'changedShip',
                        to = 'CHOOSE_COMMAND',
                    },
                    StateTransition.new{
                        from = 'CHOOSE_COMMAND',
                        event = 'moreCommandsToChoose',
                        to = 'CHOOSE_COMMAND',
                    },
                    StateTransition.new{
                        from = 'CHOOSE_COMMAND',
                        event = 'allCommandsChosen',
                        to = 'SIMULATING',
                        callback = function()
                            self:setActiveShip(1)
                        end,
                    },
                    StateTransition.new{
                        from = 'SIMULATING',
                        event = 'steerInputRequired',
                        to = 'STEER_INPUT',
                    },
                    StateTransition.new{
                        from = 'STEER_INPUT',
                        event = 'steerInputGiven',
                        to = 'SIMULATING',
                    },
                    StateTransition.new{
                        from = 'SIMULATING',
                        event = 'accelerateInputRequired',
                        to = 'ACCELERATE_INPUT',
                    },
                    StateTransition.new{
                        from = 'ACCELERATE_INPUT',
                        event = 'accelerateInputGiven',
                        to = 'SIMULATING',
                    },
                    StateTransition.new{
                        from = 'SIMULATING',
                        event = 'decelerateInputRequired',
                        to = 'DECELERATE_INPUT',
                    },
                    StateTransition.new{
                        from = 'DECELERATE_INPUT',
                        event = 'decelerateInputGiven',
                        to = 'SIMULATING',
                    },
                    StateTransition.new{
                        from = 'SIMULATING',
                        event = 'aimInputRequired',
                        to = 'AIM_INPUT',
                    },
                    StateTransition.new{
                        from = 'AIM_INPUT',
                        event = 'aimInputGiven',
                        to = 'SIMULATING',
                    },
                    StateTransition.new{
                        from = 'SIMULATING',
                        event = 'moreShipsToSimulate',
                        to = 'SIMULATING',
                        callback = function()
                            self:nextShip()
                        end,
                    },
                    StateTransition.new{
                        from = 'SIMULATING',
                        event = 'allShipsSimulated',
                        to = 'CHOOSE_COMMAND',
                        callback = function()
                            self:setActiveShip(1)
                        end,
                    },
                },
                stateCallbacks = {
                    ['CHOOSE_COMMAND'] = {
                        enter = function(fsm)
                            local activeShip = self:getActiveShip()
                            self:centerCameraOn(v(activeShip.movement.x, activeShip.movement.y))

                            commandWidget:open(activeShip)
                            local availableCommands = activeShip:availableCommands()
                            local commandIdx = commandWidget.selectedIndex
                            
                            controller:getOverlay():enable{
                                OverlayUIAction.new{
                                    label = 'Action',
                                    buttons = {'left', 'right'},
                                    callback = function(_, btn)
                                        commandIdx = clamp(commandIdx + (btn == 'left' and -1 or 1), 1, #availableCommands)
                                        commandWidget:setSelectedIndex(commandIdx)
                                    end,
                                },
                                OverlayUIAction.new{
                                    label = 'Ship',
                                    buttons = {'up', 'down'},
                                    callback = function(_, btn)
                                        if btn == 'up' then 
                                            self:nextShip() 
                                        else 
                                            self:previousShip()
                                        end
                                        fsm:mustTrigger('changedShip')
                                    end,
                                },
                                OverlayUIAction.new{
                                    label = 'Select',
                                    button = 'a',
                                    callback = function()
                                        activeShip:enqueueCommand(availableCommands[commandIdx])

                                        local allCommandsChosen = true
                                        for _, ship in ipairs(game.ships) do
                                            if ship:needsCommand() then
                                                allCommandsChosen = false
                                                break
                                            end
                                        end
                                        if allCommandsChosen then
                                            fsm:mustTrigger('allCommandsChosen')
                                            return
                                        else
                                            if not activeShip:needsCommand() then
                                                self:nextShip()
                                            end
                                            fsm:mustTrigger('moreCommandsToChoose')
                                        end
                                    end,
                                }
                            }
                        end,
                        leave = function()
                            controller:getOverlay():enable{}
                            commandWidget:close()
                        end,
                    },
                    ['SIMULATING'] = {
                        enter = function()
                            local activeShip = self:getActiveShip()
                            self:centerCameraOn(v(activeShip.movement.x, activeShip.movement.y))
                        end,
                        leave = function()
                            
                        end,
                    },
                    ['STEER_INPUT'] = {
                        enter = function(fsm)
                            local ship = self:getActiveShip()
                            local cmd = typeGuard('SteerCommand', ship:currentCommand())
                            local min, max = cmd:getTargetBearingRange()
                            local args = {target = self:getActiveShip().movement.bearing}

                            controller:getOverlay():enable{
                                OverlayUIAction.new{
                                    label = 'Steer',
                                    button = 'crank',
                                    callback = function(_, _, crank)
                                        args.target = clamp(
                                            args.target + crank.change * bearingChangePerCrankDegree,
                                            min,
                                            max
                                        )
                                        self:renderProjection(ship, ship.movement.velocity, args.target)
                                    end,
                                },
                                OverlayUIAction.new{
                                    label = 'Confirm',
                                    button = 'a',
                                    callback = function()
                                        self:setNextCommandArgs(args)
                                        fsm:mustTrigger('steerInputGiven')
                                    end,
                                }
                            }
                        end,
                        leave = function()
                            controller:getOverlay():disable()
                            self:clearProjection()
                        end,
                    },
                    ['ACCELERATE_INPUT'] = {
                        enter = function(fsm)
                            local ship = self:getActiveShip()
                            local cmd = typeGuard('AccelerateCommand', ship:currentCommand())
                            local min, max = cmd:getTargetVelocityRange()
                            local args = {target = self:getActiveShip().movement.velocity}

                            controller:getOverlay():enable{
                                OverlayUIAction.new{
                                    label = 'Accelerate',
                                    button = 'crank',
                                    callback = function(_, _, crank)
                                        args.target = clamp(
                                            args.target + crank.change * bearingChangePerCrankDegree,
                                            min,
                                            max
                                        )
                                        self:renderProjection(ship, args.target, ship.movement.bearing)
                                    end,
                                },
                                OverlayUIAction.new{
                                    label = 'Confirm',
                                    button = 'a',
                                    callback = function()
                                        self:setNextCommandArgs(args)
                                        fsm:mustTrigger('accelerateInputGiven')
                                    end,
                                }
                            }
                        end,
                        leave = function()
                            controller:getOverlay():disable()
                            self:clearProjection()
                        end,
                    },
                    ['DECELERATE_INPUT'] = {
                        enter = function(fsm)
                            local ship = self:getActiveShip()
                            local cmd = typeGuard('DecelerateCommand', ship:currentCommand())
                            local min, max = cmd:getTargetVelocityRange()
                            local args = {target = self:getActiveShip().movement.velocity}

                            controller:getOverlay():enable{
                                OverlayUIAction.new{
                                    label = 'Decelerate',
                                    button = 'crank',
                                    callback = function(_, _, crank)
                                        args.target = clamp(
                                            args.target - crank.change * bearingChangePerCrankDegree,
                                            min,
                                            max
                                        )
                                        self:renderProjection(ship, args.target, ship.movement.bearing)
                                    end,
                                },
                                OverlayUIAction.new{
                                    label = 'Confirm',
                                    button = 'a',
                                    callback = function()
                                        self:setNextCommandArgs(args)
                                        fsm:mustTrigger('decelerateInputGiven')
                                    end,
                                }
                            }
                        end,
                        leave = function()
                            controller:getOverlay():disable()
                            self:clearProjection()
                        end,
                    },
                    ['AIM_INPUT'] = {
                        enter = function(fsm)
                            local ship = self:getActiveShip()
                            local cmd = typeGuard('AimCommand', ship:currentCommand())
                            local min, max = cmd:getOrientationRange()
                            local args = {target = cmd:getCurrentOrientation()}
                            local aimX, aimY = cmd:getFrom()
                            local aimFrom = v(aimX - ship.movement.x, aimY - ship.movement.y)

                            controller:getOverlay():enable{
                                OverlayUIAction.new{
                                    label = 'Rotate',
                                    button = 'crank',
                                    callback = function(_, _, crank)
                                        args.target = clamp(
                                            args.target + crank.change * bearingChangePerCrankDegree,
                                            min,
                                            max
                                        )
                                        self:renderAim(aimFrom, args.target, cmd:getRange(), cmd:getSpread())
                                    end,
                                },
                                OverlayUIAction.new{
                                    label = 'Confirm',
                                    button = 'a',
                                    callback = function()
                                        self:setNextCommandArgs(args)
                                        fsm:mustTrigger('aimInputGiven')
                                    end,
                                }
                            }
                        end,
                        leave = function()
                            controller:getOverlay():disable()
                            self:clearProjection()
                        end,
                    },
                },
            }
        end,

        -- begin UILifecycle
        
        onOpen = function(self)
            
        end,

        onClose = function(self) 
            
        end,

        onSuspend = function(self)
            
        end,

        onResume = function(self)
            
        end,

        update = function(self)
            self.taskQueue:update()

            if self.fsm.state == 'SIMULATING' then
                local activeShip = self:getActiveShip()
                local args = self:consumeNextCommandArgs()
                if activeShip:update(DeltaTime.getSeconds(), args) then
                    if activeShip:needsCommand() then
                        self:continueSimulationOrFinish()
                    else
                        self:transitionToCommandInput()
                    end
                end
            end

            util.gfx.withDrawOffset(-self.camera.x, -self.camera.y, function(g)
                for _, ship in ipairs(self.game.ships) do
                    self:renderShipImg():drawWithTransform(geom.affineTransform.new():rotatedBy(ship.movement.bearing), ship.movement.x, ship.movement.y)
                end
                util.gfx.withImageDrawMode(g.kDrawModeNXOR, function(g)
                    if self.shipProjectionImg ~= nil then
                        self.shipProjectionImg:drawCentered(self:getActiveShip().movement.x, self:getActiveShip().movement.y)
                    end
                end)
            end)

            self.commandWidget:update()
        end,

        -- end UILifecycle

        getActiveShip = function(self)
            return self.game.ships[self.activeShipIdx]
        end,

        setActiveShip = function(self, idx)
            idx = typeGuard('number', idx or 1)
            self.activeShipIdx = cycle(idx, 1, #self.game.ships)
        end,

        nextShip = function(self)
            self:setActiveShip(self.activeShipIdx + 1)
        end,

        previousShip = function(self)
            self:setActiveShip(self.activeShipIdx - 1)
        end,

        centerCameraOn = function(self, pos, immediate)
            self:moveCameraTo(pos - v(playdateScreenW / 2, playdateScreenH / 2), immediate)
        end,

        moveCameraTo = function(self, pos, immediate)
            pos = typeGuard('userdata', pos or v(0, 0))
            immediate = typeGuard('boolean', immediate or false)

            if immediate or self.camera == nil then
                self.camera = pos
                return
            end
            self.taskQueue:cancelTasksOfKind('moveCamera')
            self.taskQueue:submit(TaskQueueTask.new{
                kind = 'moveCamera',
                initialState = { 
                    timer = nil,
                    start = nil,
                },
                run = function(state)
                    if state.timer == nil then
                        state.start = self.camera:copy()
                        state.timer = Timer.new(cameraMoveTime, 0, 1)
                    end
                    if state.timer.timeLeft == 0 then
                        self.camera = pos
                        return true
                    else
                        self.camera = state.start + ((pos - state.start) * state.timer.value)
                        return false
                    end
                end,
            })
        end,

        setNextCommandArgs = function(self, args)
            self.nextCommandArgs = typeGuard('table', args)
        end,

        clearProjection = function(self)
            self.shipProjectionImg = nil
        end,

        renderAim = function(self, from, orientation, range, spread)
            self.shipProjectionImg = util.gfx.withImageContext(gfx.image.new(playdateScreenW*2, playdateScreenH*2), function(g)
                util.gfx.withDrawOffset(playdateScreenW + from.x, playdateScreenH + from.y, function(g)
                    local min, max = orientation - spread/2, orientation + spread/2
                    g.drawArc(0, 0, range, min, max)
                    g.drawLine(0, 0, range * math.sin(math.rad(min)), -range * math.cos(math.rad(min)))
                    g.drawLine(0, 0, range * math.sin(math.rad(max)), -range * math.cos(math.rad(max)))
                end)
            end)
        end,

        renderProjection = function(self, ship, targetVelocity, targetBearing)
            local stepsPerMeter = 0.1
            local dotRadius = 2
            local minSteps = 2
            local maxSteps = 20

            local avgVelocity = ((targetVelocity + ship.movement.velocity)/2)
            local approxDistance = avgVelocity * ShipCommand.durationSeconds
            local steps = clamp(math.ceil(approxDistance * stepsPerMeter), minSteps, maxSteps)
            self.shipProjectionImg = util.gfx.withImageContext(gfx.image.new(playdateScreenW*2, playdateScreenH*2), function(g)
                g.fillCircleAtPoint(playdateScreenW, playdateScreenH, dotRadius)
                for _, projection in ipairs(ship:projectMovement{targetVelocity = targetVelocity, targetBearing = targetBearing, steps = steps}) do
                    g.fillCircleAtPoint(playdateScreenW + projection.x - ship.movement.x, playdateScreenH + projection.y - ship.movement.y, dotRadius)
                end
            end)
        end,
    },
    private {
        controller = null, -- UIController
        game = null, -- GameState
        fsm = null, -- FiniteStateMachine
        taskQueue = null, -- TaskQueue
        camera = null, -- geom.vector2D
        commandWidget = null, -- CommandWidget

        activeShipIdx = 0,

        -- @see renderProjection. center of the image is current ship position.
        shipProjectionImg = null, -- gfx.image|nil

        nextCommandArgs = null, -- table|nil

        consumeNextCommandArgs = function(self)
            local args = self.nextCommandArgs
            self.nextCommandArgs = nil
            return args
        end,

        renderShipImg = memo(function(self)
            local length = 39
            local width = 15
            local prowLength = 8
            return util.gfx.withImageContext(gfx.image.new(width, length), function(g)
                g.fillTriangle(
                    0, prowLength,
                    width, prowLength,
                    width / 2, 0)
                g.fillRect(0, prowLength, width, length - prowLength)
            end)
        end),

        transitionToCommandInput = function(self)
            local requiredCommand = self:getActiveShip():currentCommand()
            if instanceOf('PassCommand', requiredCommand) then
                self:setNextCommandArgs({})
            elseif instanceOf('SteerCommand', requiredCommand) then
                self.fsm:mustTrigger('steerInputRequired')
            elseif instanceOf('AccelerateCommand', requiredCommand) then
                self.fsm:mustTrigger('accelerateInputRequired')
            elseif instanceOf('DecelerateCommand', requiredCommand) then
                self.fsm:mustTrigger('decelerateInputRequired')
            elseif instanceOf('AimCommand', requiredCommand) then
                self.fsm:mustTrigger('aimInputRequired')
            else
                error('unimplemented command type: '..requiredCommand:getType()) 
            end
        end,

        continueSimulationOrFinish = function(self)
            if self.activeShipIdx < #self.game.ships then
                self.fsm:mustTrigger('moreShipsToSimulate')
            else
                self.fsm:mustTrigger('allShipsSimulated')
            end
        end,
    }
}

class "CommandWidget" {
    public {
        static {
            boxSize = 25,
            boxMargin = 2,
            boxRadius = 2,
            distanceFromCenterY = 20,
            scrollDurationMs = 200,

            icons = memo(function() 
                local icons = {}
                for _, commandType in ipairs(ShipCommand.Type:getValues()) do
                    icons[commandType] = gfx.image.new('images/command_' .. commandType)
                    if icons[commandType] == nil then
                        error('failed to load icon for command type ' .. commandType)
                    end
                end
                return icons
            end),
        },

        __construct = function(self, args)
            args = args or {}
            self.taskQueue = TaskQueue.new()
        end,

        open = function(self, ship)
            typeGuard('Ship', ship)
            if self:isOpen() then
                self:close()
            end
            self.ship = ship
            self.cmds = ship:availableCommands()
            self.selectedIndex = math.min(self.selectedIndex, #ship:availableCommands())
            self.scroll = self.selectedIndex
        end,

        close = function(self)
            self.ship = nil
            self.cmds = {}
            self.taskQueue:cancelAll()
        end,

        isOpen = function(self)
            return self.ship ~= nil
        end,

        setSelectedIndex = function(self, idx)
            self.selectedIndex = idx
            self.taskQueue:cancelTasksOfKind('scroll')
            self.taskQueue:submit(TaskQueueTask.new{
                kind = 'scroll',
                initialState = {},
                run = function(state)
                    if state.timer == nil then
                        state.timer = Timer.new(CommandWidget.scrollDurationMs, self.scroll, idx)
                    end
                    self:setScroll(state.timer.value)
                    return state.timer.timeLeft == 0
                end,
            })
        end,

        setScroll = function(self, scroll)
            self.scroll = scroll
        end,

        update = function(self)
            if not self:isOpen() then
                return
            end

            self.taskQueue:update()

            local img = self:getImage()
            img:drawCentered(playdateScreenW/2, (playdateScreenH - img.height)/2)
        end,
    },
    private {
        getter {
            selectedIndex = 1,
        },
        ship = null, -- Ship|nil
        cmds = {}, -- ShipCommand[] cached as ship:availableCommands() expensive to call every frame
        taskQueue = null, -- TaskQueue
        scroll = 1, -- non-integer, in index units (i.e. 1.5 is half way between first and second option)

        getImage = memo(function(self)
            if not self:isOpen() then
                return gfx.image.new(0, 0)
            end
            local imgW = playdateScreenW
            local imgH = playdateScreenH/2
            
            return util.gfx.withImageContext(gfx.image.new(imgW, imgH), function(g)
                local drawBox = function(cmdT, offsetX, offsetY)
                    util.gfx.withColor(g.kColorWhite, function(g)
                        g.fillRoundRect(offsetX, offsetY, CommandWidget.boxSize, CommandWidget.boxSize, CommandWidget.boxRadius)
                    end)
                    g.drawRoundRect(offsetX, offsetY, CommandWidget.boxSize, CommandWidget.boxSize, CommandWidget.boxRadius)
                    if cmdT ~= nil then
                        CommandWidget:icons()[cmdT]:drawCentered(offsetX + CommandWidget.boxSize/2, offsetY + CommandWidget.boxSize/2)
                    end
                end

                local centerX = (imgW - CommandWidget.boxSize)/2
                local boxSpacing = CommandWidget.boxSize + CommandWidget.boxMargin
                local row = 1
                local rowOffsetY = function()
                    return imgH - CommandWidget.distanceFromCenterY - boxSpacing*row
                end
                if self.ship:needsCommand() then
                    for idx, cmd in ipairs(self.cmds) do
                        local offsetX = centerX + (idx - self.scroll) * boxSpacing
                        drawBox(cmd:getType(), offsetX, rowOffsetY())
                    end
                    row += 1
                end
                for i = self.ship.stats.inertia - (self.ship:needsCommand() and 1 or 0), 1, -1 do
                    local cmd = self.ship.commands[i]
                    drawBox(cmd ~= nil and cmd:getType() or nil, centerX, rowOffsetY())
                    row += 1
                end
            end)
        end, {extractKeys = function(self)
            local cmdTypes = ''
            for _, cmd in ipairs(self.ship.commands) do
                cmdTypes = cmdTypes .. '.' .. cmd:getType()
            end
            return {self.selectedIndex, self.scroll, ship, self:isOpen()}
        end})
    }
}
