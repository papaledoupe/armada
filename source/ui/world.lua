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
import 'ui/ship'
import 'ui/damage'

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
            
            local game = typeGuard('GameState', args.game or error('game required'))
            self.ships = {}
            for _, ship in ipairs(game.ships) do
                table.insert(self.ships, ShipUI.new{ship = ship})
            end
            
            local commandSelector = CommandSelector.new()
            self.commandSelector = commandSelector

            self:setActiveShip(args.activeShipIdx or 1)

            self.taskQueue = TaskQueue.new()

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
                        to = 'FIRING',
                    },
                    StateTransition.new{
                        from = 'FIRING',
                        event = 'firingComplete',
                        to = 'CHOOSE_COMMAND',
                        callback = function()
                            self:setActiveShip(1)
                        end,
                    }
                },
                stateCallbacks = {
                    ['CHOOSE_COMMAND'] = {
                        enter = function(fsm)
                            local activeShip = self:getActiveShip().ship
                            self:centerCameraOn(v(activeShip.movement.x, activeShip.movement.y))

                            commandSelector:open(activeShip)
                            local availableCommands = activeShip:availableCommands()
                            local commandIdx = commandSelector.selectedIndex
                            
                            controller:getOverlay():enable{
                                OverlayUIAction.new{
                                    label = 'Action',
                                    buttons = {'left', 'right'},
                                    callback = function(_, btn)
                                        commandIdx = clamp(commandIdx + (btn == 'left' and -1 or 1), 1, #availableCommands)
                                        commandSelector:setSelectedIndex(commandIdx)
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
                            commandSelector:close()
                        end,
                    },
                    ['SIMULATING'] = {
                        enter = function()
                            local activeShip = self:getActiveShip().ship
                            self:centerCameraOn(v(activeShip.movement.x, activeShip.movement.y))
                        end,
                        leave = function()
                            
                        end,
                    },
                    ['STEER_INPUT'] = {
                        enter = function(fsm)
                            local ship = self:getActiveShip()
                            local cmd = typeGuard('SteerCommand', ship.ship:currentCommand())
                            local min, max = cmd:getTargetBearingRange()
                            local args = {target = ship.ship.movement.bearing}

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

                                        ship:renderProjection(ship.ship.movement.velocity, args.target)
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
                            self:getActiveShip():clearProjection()
                        end,
                    },
                    ['ACCELERATE_INPUT'] = {
                        enter = function(fsm)
                            local ship = self:getActiveShip()
                            local cmd = typeGuard('AccelerateCommand', ship.ship:currentCommand())
                            local min, max = cmd:getTargetVelocityRange()
                            local args = {target = ship.ship.movement.velocity}

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
                                        ship:renderProjection(args.target, ship.ship.movement.bearing)
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
                            self:getActiveShip():clearProjection()
                        end,
                    },
                    ['DECELERATE_INPUT'] = {
                        enter = function(fsm)
                            local ship = self:getActiveShip()
                            local cmd = typeGuard('DecelerateCommand', ship.ship:currentCommand())
                            local min, max = cmd:getTargetVelocityRange()
                            local args = {target = ship.ship.movement.velocity}

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
                                        ship:renderProjection(args.target, ship.ship.movement.bearing)
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
                            self:getActiveShip():clearProjection()
                        end,
                    },
                    ['AIM_INPUT'] = {
                        enter = function(fsm)
                            local ship = self:getActiveShip()
                            local cmd = typeGuard('AimCommand', ship.ship:currentCommand())
                            local min, max = cmd:getOrientationRange()
                            local args = {target = cmd:getCurrentOrientation()}
                            local aimX, aimY = cmd:getFrom()
                            local aimFrom = v(aimX - ship.ship.movement.x, aimY - ship.ship.movement.y)

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
                                        ship:activateSponson(cmd.sponsonIdx, args.target)
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
                            self:getActiveShip():deactivateSponson()
                        end,
                    },
                    ['FIRING'] = {
                        enter = function(fsm)
                            controller:getOverlay():disable()
                            local attacks = {}
                            for _, ship in ipairs(self.ships) do
                                for _, target in ipairs(self.ships) do
                                    local sponsons = ship.ship:getSponsonsInRangeOf(target.ship.movement.x, target.ship.movement.y)
                                    for _, sponson in ipairs(sponsons) do
                                        table.insert(attacks, {source = ship, target = target, sponson = sponson})
                                    end
                                end
                            end

                            local lastSourceShip = self:getActiveShip()
                            for _, attack in ipairs(attacks) do
                                if attack.source ~= lastSourceShip then
                                    self:centerCameraOn(v(attack.source.ship.movement.x, attack.source.ship.movement.y))
                                end
                                lastSourceShip = attack.source
                                self:resolveAttack(attack.source, attack.target, attack.sponson)
                            end
                            self.taskQueue:submit(TaskQueueTask.new{
                                kind = 'triggerFiringComplete',
                                run = function()
                                    fsm:mustTrigger('firingComplete')
                                    return true
                                end,
                            })
                        end,
                    }
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
                local activeShip = self:getActiveShip().ship
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
                for _, ship in ipairs(self.ships) do
                    ship:draw()
                end
            end)

            self.commandSelector:update()

            if self.damageCheck ~= nil then
                self.damageCheck:update()
            end
        end,

        -- end UILifecycle

        getActiveShip = function(self)
            return self.ships[self.activeShipIdx]
        end,

        setActiveShip = function(self, idx)
            idx = typeGuard('number', idx or 1)
            self.activeShipIdx = cycle(idx, 1, #self.ships)
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

        resolveAttack = function(self, attacker, defender, sponson)
            -- TODO find maxDamage based on range
            -- TODO apply damage

            local complete = false
            self.damageCheck = DamageCheckUI.new{
                check = DamageCheck.new{maxDamage = 10},
                overlay = self.controller:getOverlay(),
                onComplete = function(chk)
                    print('check complete', chk)
                    complete = true
                    self:closeDamageCheck()
                end,
            }
            self.taskQueue:submit(TaskQueueTask.new{
                kind = 'resolveAttack',
                run = function()
                    return complete
                end,
            })
        end,

        closeDamageCheck = function(self)
            self.damageCheck = nil
        end,
    },
    private {
        controller = null, -- UIController
        game = null, -- GameState
        ships = {}, -- ShipUI[]
        fsm = null, -- FiniteStateMachine
        taskQueue = null, -- TaskQueue
        camera = null, -- geom.vector2D
        commandSelector = null, -- CommandSelector
        damageCheck = null, -- DamageCheckUI|nil

        activeShipIdx = 0,

        nextCommandArgs = null, -- table|nil

        consumeNextCommandArgs = function(self)
            local args = self.nextCommandArgs
            self.nextCommandArgs = nil
            return args
        end,

        transitionToCommandInput = function(self)
            local requiredCommand = self:getActiveShip().ship:currentCommand()
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
            if self.activeShipIdx < #self.ships then
                self.fsm:mustTrigger('moreShipsToSimulate')
            else
                self.fsm:mustTrigger('allShipsSimulated')
            end
        end,
    }
}

class "CommandSelector" {
    public {
        static {
            boxSize = 28,
            boxMargin = 3,
            boxRadius = 3,
            arrowHeight = 20,
            arrowWidth = 10,

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

            drawBox = function(self, cmdT, offsetX, offsetY, inverted)
                inverted = inverted or false
                util.gfx.withColor(inverted and gfx.kColorBlack or gfx.kColorWhite, function(g)
                    g.fillRoundRect(offsetX, offsetY, self.boxSize, self.boxSize, self.boxRadius)
                end)
                gfx.drawRoundRect(offsetX, offsetY, self.boxSize, self.boxSize, self.boxRadius)
                if cmdT ~= nil then
                    util.gfx.withImageDrawMode(inverted and gfx.kDrawModeInverted or gfx.kDrawModeCopy, function(g)
                        CommandSelector:icons()[cmdT]:drawCentered(offsetX + self.boxSize/2, offsetY + self.boxSize/2)
                    end)
                end
            end,

            drawArrow = function(self, offsetX, offsetY)
                local x1, y1 = offsetX, offsetY + math.ceil((self.boxSize - self.arrowHeight)/2)
                gfx.fillTriangle(x1, y1, x1, y1 + self.arrowHeight, x1 + self.arrowWidth, y1 + math.ceil(self.arrowHeight/2))
            end,
        },

        open = function(self, ship)
            typeGuard('Ship', ship)
            if self:isOpen() then
                self:close()
            end
            self.ship = ship
            self.cmds = ship:availableCommands()
            self.selectedIndex = math.min(self.selectedIndex, #self.cmds)
        end,

        close = function(self)
            self.ship = nil
            self.cmds = {}
        end,

        isOpen = function(self)
            return self.ship ~= nil
        end,

        setSelectedIndex = function(self, idx)
            self.selectedIndex = idx
        end,

        setScroll = function(self, scroll)
            self.scroll = scroll
        end,

        update = function(self)
            if not self:isOpen() then
                return
            end

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

        getImage = memo(function(self)
            if not self:isOpen() then
                return gfx.image.new(0, 0)
            end
            local imgW = playdateScreenW
            local imgH = playdateScreenH/2
            
            return util.gfx.withImageContext(gfx.image.new(imgW, imgH), function(g)
                local currentX = self.boxMargin
                if self.ship:needsCommand() then
                    for idx, cmd in ipairs(self.cmds) do
                        local offsetY = self.boxMargin
                        self:drawBox(cmd:getType(), currentX, self.boxMargin, idx == self.selectedIndex)
                        currentX = currentX + (self.boxSize + self.boxMargin)
                    end
                end

                for i = 1, self.ship.stats.inertia do
                    if i > 1 or self.ship:needsCommand() then
                        self:drawArrow(currentX, self.boxMargin)
                        currentX = currentX + (self.arrowWidth + self.boxMargin)
                    end

                    local cmd = self.ship.commands[i]
                    self:drawBox(cmd ~= nil and cmd:getType() or nil, currentX, self.boxMargin)
                    currentX = currentX + (self.boxSize + self.boxMargin)
                end

            end)
        end, {extractKeys = function(self)
            return {self.selectedIndex, self.scroll, self.ship, self:isOpen()}
        end})
    }
}
