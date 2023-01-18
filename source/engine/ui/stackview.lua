import 'CoreLibs/graphics'
import 'util/gfx'
local gfx <const> = playdate.graphics
local geom <const> = playdate.geometry
local timer <const> = playdate.timer
import 'util/task'
import 'util/oo'
local typeGuard <const> = util.oo.typeGuard
local typeGuardElements <const> = util.oo.typeGuardElements
local interface <const> = util.oo.interface

local playdateScreenW <const> = 400
local playdateScreenH <const> = 240
local defaultOffset <const> = 50
local slideDurationMs <const> = 150 -- duration of stack push/pop animation
-- https://dev.playdate.store/tools/gfxp/
local depth1Pattern <const> = {0x7F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 128, 0, 0, 0, 0, 0, 0, 0}
local depth2Pattern <const> = {0x66, 0xFF, 0xFF, 0x66, 0x66, 0xFF, 0xFF, 0x66, 153, 0, 0, 153, 153, 0, 0, 153}
local shadeLevel = 9 -- shade applied to non-top elements
local rimWidth = 2

interface "StackViewElement" {
    "update", -- called once per frame, only when on top, with geom.size giving the width and height, which will not vary between calls to update() unless the stack view is reused after being popped
    "snapshot", -- return playdate.graphics.image; generate a still image of the element to be displayed while not on top
    "getOffset", -- return horizontal px offset relative to lower element
}

class "StackView" {
    public {
        __construct = function(self, args)
            args = args or {}
            self.viewport = typeGuard('userdata', args.viewport or geom.rect.new(0, 0, playdateScreenW, playdateScreenH))
            self.offset = typeGuard('number', args.offset or defaultOffset)
            self.stack = {typeGuard('StackViewElement', args.start or error('start required'))}
            self.taskQueue = TaskQueue.new()
        end,

        push = function(self, element)
            typeGuard('StackViewElement', element)
            self.taskQueue:submit(TaskQueueTask.new{
                kind = 'push',
                initialState = { timer = nil },
                run = function(state)
                    if state.timer == nil then
                        local prev = self:top()
                        table.insert(self.stack, element)
                        if prev ~= nil then
                            table.insert(self.snapshotStack, prev:snapshot())
                            self.stackBgImg = nil
                            self.stackShade = 0
                        end
                        state.timer = timer.new(slideDurationMs, playdateScreenW, self:getOffsetAtDepth(self:getDepth()))
                    end
                    self.stackShade = util.gfx.getShadeFromTimer(0, shadeLevel, state.timer)
                    self.topOffset = state.timer.value
                    return state.timer.timeLeft == 0
                end,
            })
            self.stackBgImg = nil
        end,

        pop = function(self, args)
            args = args or {}
            local n = typeGuard('number', args.n or 1)
            -- rather than popping the last view on the stack, calls this function if given
            local callbackOnEmpty = nil
            if args.callbackOnEmpty ~= nil then
                callbackOnEmpty = typeGuard('function', args.callbackOnEmpty)
            end

            for i = 1, n do
                self.taskQueue:submit(TaskQueueTask.new{
                    kind = 'pop',
                    initialState = { timer = nil },
                    run = function(state)
                        if state.timer == nil then
                            if callbackOnEmpty ~= nil and self:getDepth() == 1 then
                                callbackOnEmpty()
                                return true
                            end
                            state.timer = timer.new(slideDurationMs, self:getOffsetAtDepth(self:getDepth()), playdateScreenW)
                        end
                        self.topOffset = state.timer.value
                        self.stackShade = util.gfx.getShadeFromTimer(shadeLevel, 0, state.timer)
                        if state.timer.timeLeft == 0 then
                            table.remove(self.snapshotStack)
                            self.stackBgImg = nil
                            self.stackShade = shadeLevel
                            table.remove(self.stack)
                            self.topOffset = self:getOffsetAtDepth(self:getDepth())
                            return true
                        end
                        return false
                    end,
                })
            end
        end,

        update = function(self)
            self.taskQueue:update()

            local top = self:top()
            if top == nil then
                return
            end
            
            if self.stackBgImg == nil then
                self:renderStackBg()
            end
            self.stackBgImg:draw(self.viewport.left, self.viewport.top)
            self:drawShade(self:getDepth(), self.stackShade)

            util.gfx.withDrawOffset(self.viewport.left + self.topOffset, self.viewport.top, function()
                local size = self.viewport.size:copy()
                size.width -= self:getOffsetAtDepth(self:getDepth())
                top:update(size)
            end)
            self:drawRim(self.viewport.left + self.topOffset)
        end,

        getDepth = function(self)
            return #self.stack
        end,

        top = function(self)
            return self.stack[#self.stack]
        end,
    },
    private {
        offset = 0, -- horizontal offset between stack elements
        topOffset = 0, -- animated current offset of top element
        viewport = null, -- geom.rect
        snapshotStack = {}, --[]gfx.image: snapshot image of each element in the stack except top
        stackBgImg = null, -- gfx.image: pre-rendered img of all elements in the stack except top
        stackShade = 0, -- shade level cast by top element
        stack = {}, -- []StackViewElement
        taskQueue = null, -- TaskQueue

        getOffsetAtDepth = function(self, depth)
            return (depth - 1) * self.offset
        end,

        renderStackBg = function(self)
            self.stackBgImg = gfx.image.new(self.viewport.width, self.viewport.height)
            util.gfx.withImageContext(self.stackBgImg, function(g)
                for i, element in ipairs(self.stack) do
                    if i < #self.stack then
                        local off = self:getOffsetAtDepth(i)
                        self.snapshotStack[i]:draw(off, 0)
                        self:drawRim(off)
                        self:drawShade(i, shadeLevel)
                    end
                end
            end)
        end,

        drawShade = function(self, depth, level)
            if level < 1 then 
                return 
            end
            local offset = self:getOffsetAtDepth(depth - 1)
            local top = depth == #self.stack
            local width = self.offset
            if top then
                width = playdateScreenW - offset
            end

            local rect = geom.rect.new(offset, 0, width, playdateScreenH)
            util.gfx.withShade(level, function(g) g.fillRect(rect) end)
        end,

        drawRim = function(self, offset)
            util.gfx.withColor(gfx.kColorBlack, function(g)
                g.fillRect(offset - rimWidth, 0, rimWidth, playdateScreenH)
            end)
        end,
    }
}
