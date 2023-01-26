import 'CoreLibs/graphics'
import 'CoreLibs/timer'
local timer <const> = playdate.timer
local gfx <const> = playdate.graphics
local geom <const> = playdate.geometry
import 'damage/check'
import 'util/oo'
local typeGuard <const> = util.oo.typeGuard
import 'util/task'
import 'util/fsm'
import 'util/gfx'
import 'util/memo'
local memo <const> = util.memo

local playdateScreenW <const> = 400
local playdateScreenH <const> = 240

local cardHeightToWidthRatio <const> = 3.5/2.5
local cardSize <const> = geom.size.new(100, cardHeightToWidthRatio*100)
local cardCornerRadius <const> = 8
local cardBorderWidth <const> = 3
local drawnCardsOffsetX <const> = 50 -- offset of first drawn card
local drawnCardsOffsetY <const> = 80 -- offset of first drawn card
local drawnCardOffsetX <const> = 40 -- additional X offset for subsequent cards
local drawnCardOffsetJitterX <const> = 5 -- cards will have random X offset +/- this amount of px
local drawnCardOffsetJitterY <const> = 5 -- cards will have random Y offset +/- this amount of px
local drawnCardRotationJitter <const> = 2 -- cards will have random rotation +/- this amount of deg

local drawStartX <const> = playdateScreenW
local drawStartY <const> = playdateScreenH
local drawStartRot <const> = 0
local drawDurationMs <const> = 200

local pointerSize <const> = 10
local pointerMargin <const> = 3
local progressBarSize <const> = geom.size.new(playdateScreenW, 20)
local progressBarOffset <const> = geom.point.new((playdateScreenW - progressBarSize.width)/2, 20)
local progressBarZeroRegionWidth <const> = 140
local progressBarBustRegionWidth <const> = 70
local progressBarDamageRegionWidth <const> = progressBarSize.width - progressBarZeroRegionWidth - progressBarBustRegionWidth

class "DamageCheckUI" {
    public {
        __construct = function(self, args)
            self.check = typeGuard('DamageCheck', args.check or error('check required'))
            local overlay = typeGuard('OverlayUI', args.overlay or error('overlay required'))
            local onComplete = typeGuard('function', args.onComplete or function(dmgCheck) end)
            
            self.taskQueue = TaskQueue.new()

            self.cardsImage = gfx.image.new(playdateScreenW, playdateScreenH)

            local drawnCount = 0
            local taskQueue = self.taskQueue
            local check = self.check
            self.fsm = FiniteStateMachine.new{
                start = 'DRAW',
                transitions = {
                    StateTransition.new{from = 'AWAIT_INPUT', event = 'draw', to = 'DRAW'},
                    StateTransition.new{from = 'DRAW', event = 'drawn', to = 'AWAIT_INPUT'},
                    StateTransition.new{from = 'DRAW', event = 'maxScore', to = 'MAX_SCORE'},
                    StateTransition.new{from = 'AWAIT_INPUT', event = 'stick', to = 'COMPLETE'},
                    StateTransition.new{from = 'MAX_SCORE', event = 'stick', to = 'COMPLETE'},
                },
                stateCallbacks = {
                    ['DRAW'] = {
                        enter = function(fsm)
                            overlay:disable()
                            local cards, scores = check:draw()
                            for i, card in ipairs(cards) do
                                drawnCount += 1
                                local targetX, targetY, targetRot = self:cardTransform(drawnCount)
                                local img = self:renderCardImage(card)
                                taskQueue:submit(TaskQueueTask.new{
                                    kind = 'drawCard',
                                    initialState = {
                                        card = card,
                                        timer = nil,
                                        startProgress = nil,
                                    },
                                    run = function(state)
                                        if state.timer == nil then
                                            state.timer = timer.new(drawDurationMs, 0, 1)
                                        end
                                        if state.startProgress == nil then
                                            state.startProgress = self.progress
                                        end
                                        local progress = state.timer.value
                                        
                                        self:setPointerProgress(state.startProgress + (scores[i] - state.startProgress) * progress)

                                        local x = cardSize.width/2 + drawStartX + (targetX - drawStartX) * progress
                                        local y = cardSize.height/2 + drawStartY + (targetY - drawStartY) * progress
                                        local rot = drawStartRot + (targetRot - drawStartRot) * progress
                                        img:drawRotated(x, y, rot)
                                        if state.timer.timeLeft == 0 then
                                            util.gfx.withImageContext(self.cardsImage, function(g)
                                                img:drawRotated(x, y, rot)
                                            end)
                                            return true
                                        end
                                        return false
                                    end,
                                })
                                taskQueue:submit(TaskQueueTask.new{
                                    kind = 'delayAfterDraw',
                                    initialState = {
                                        timer = nil,
                                    },
                                    run = function(state)
                                        if state.timer == nil then
                                            state.timer = timer.new(drawDurationMs, 0, 1)
                                        end
                                        return state.timer.timeLeft == 0 
                                    end,
                                })
                            end
                            taskQueue:submit(TaskQueueTask.new{
                                kind = 'finishedDrawing',
                                run = function()
                                    if check.score == check.maxScore then
                                        fsm:mustTrigger('maxScore')
                                    else
                                        fsm:mustTrigger('drawn')
                                    end
                                    return true
                                end,
                            })
                        end,
                    },
                    ['AWAIT_INPUT'] = {
                        enter = function(fsm)
                            overlay:enable{
                                OverlayUIAction.new{
                                    button = 'b',
                                    label = 'Stick',
                                    callback = function()
                                        fsm:mustTrigger('stick')
                                    end,
                                },
                                OverlayUIAction.new{
                                    button = 'a',
                                    label = 'Draw',
                                    callback = function()
                                        fsm:mustTrigger('draw')
                                    end,
                                },
                            }
                        end,
                    },
                    ['MAX_SCORE'] = {
                        enter = function(fsm)
                            overlay:enable{
                                OverlayUIAction.new{
                                    button = 'b',
                                    label = 'Stick',
                                    callback = function()
                                        fsm:mustTrigger('stick')
                                    end,
                                },
                            }
                        end,
                    },
                    ['COMPLETE'] = {
                        enter = function(fsm)
                            onComplete(check)
                        end,
                    },
                }
            }
        end,

        update = function(self)
            self.cardsImage:draw(0, 0)
            self.taskQueue:update()

            self:renderProgressImage():draw(progressBarOffset)
            local pointer = self:renderProgressPointer()
            pointer:draw(progressBarOffset:offsetBy(-pointer.width/2 + self:getPointerOffset(), -pointer.height - pointerMargin))
        end,

        cardTransform = function(self, i)
            local x = drawnCardsOffsetX + (i - 1) * drawnCardOffsetX + math.random(-drawnCardOffsetJitterX, drawnCardOffsetJitterX)
            local y = drawnCardsOffsetY + math.random(-drawnCardOffsetJitterY, drawnCardOffsetJitterY)
            local r = math.random(-drawnCardRotationJitter, drawnCardRotationJitter)
            return x, y, r
        end,

        renderCardImage = function(self, card)
            return util.gfx.withImageContext(gfx.image.new(cardSize.width, cardSize.height), function(g)
                util.gfx.withColor(g.kColorWhite, function(g)
                    g.fillRoundRect(0, 0, cardSize.width, cardSize.height, cardCornerRadius)
                end)
                util.gfx.withLineWidth(cardBorderWidth, function(g)
                    g.drawRoundRect(0, 0, cardSize.width, cardSize.height, cardCornerRadius)
                end)
                g.drawTextInRect('*'..card.str..'*', cardCornerRadius, cardCornerRadius, cardSize.width, cardSize.height)
            end)
        end,

        renderProgressPointer = memo(function(self)
            return util.gfx.withImageContext(gfx.image.new(pointerSize, pointerSize), function(g)
                g.fillTriangle(0, 0, pointerSize, 0, pointerSize/2, pointerSize)
            end)
        end),

        getPointerOffset = function(self)
            local damageLevels = self.check:damageLevels()
            if self.progress == 0 then
                return 0
            elseif self.progress < damageLevels[1] then
                return progressBarZeroRegionWidth * (self.progress - 0.5)/(damageLevels[1] - 1)
            elseif self.progress <= damageLevels[#damageLevels] then
                return progressBarZeroRegionWidth + progressBarDamageRegionWidth * (self.progress - damageLevels[1] + 0.5)/(damageLevels[#damageLevels] - damageLevels[1] + 1)
            else
                return progressBarZeroRegionWidth + progressBarDamageRegionWidth + progressBarBustRegionWidth/2
            end
        end,

        setPointerProgress = function(self, p)
            self.progress = p
        end,

        -- TODO memoize
        renderProgressImage = function(self)
            local damageLevels = self.check:damageLevels()
            return util.gfx.withImageContext(gfx.image.new(progressBarSize.width, progressBarSize.height * 2), function(g)
                local rect = geom.rect.new(0, 0, progressBarZeroRegionWidth, progressBarSize.height)
                g.fillRect(rect)
                util.gfx.withImageDrawMode(g.kDrawModeFillWhite, function(g)
                    g.drawTextInRect('*MISS*', rect, nil, nil, kTextAlignment.center)
                end)
                g.drawTextInRect('0-'..tostring(damageLevels[1] - 1), rect:offsetBy(0, progressBarSize.height), nil, nil, kTextAlignment.center)
                
                local damageCellWidth = progressBarDamageRegionWidth / #damageLevels
                local damageCellRemainder = progressBarDamageRegionWidth % #damageLevels
                local left = progressBarZeroRegionWidth
                for i = 1, #damageLevels do
                    local cellWidth = damageCellWidth
                    if damageCellRemainder > 0 then
                        cellWidth += 1
                        damageCellRemainder -= 1
                    end
                    rect = geom.rect.new(left, 0, cellWidth, progressBarSize.height)
                    g.drawRect(rect)
                    g.drawTextInRect('*'..i..'*', rect, nil, nil, kTextAlignment.center)
                    g.drawTextInRect(tostring(damageLevels[i]), rect:offsetBy(0, progressBarSize.height), nil, nil, kTextAlignment.center)
                    left += cellWidth
                end

                rect = geom.rect.new(left, 0, progressBarBustRegionWidth, progressBarSize.height)
                g.fillRect(rect)
                util.gfx.withImageDrawMode(g.kDrawModeFillWhite, function(g)
                    g.drawTextInRect('*MISS*', rect, nil, nil, kTextAlignment.center)
                end)
                g.drawTextInRect('22+', rect:offsetBy(0, progressBarSize.height), nil, nil, kTextAlignment.center)
            end)
        end,
    },
    private {
        fsm = null, -- FiniteStateMachine
        taskQueue = null, -- TaskQueue
        check = null, -- DamageCheck
        cardsImage = null, -- gfx.image (image of previously drawn cards no longer being animated)
        getter {
            progress = 0,
        }
    }
}
