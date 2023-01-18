import "CoreLibs/timer"
import "CoreLibs/graphics"
import 'util/oo'
import 'util/enum'
import 'util/gfx'
import 'util/task'
local typeGuard <const> = util.oo.typeGuard
local timer <const> = playdate.timer
local gfx <const> = playdate.graphics
local geom <const> = playdate.geometry
local Follow <const> = util.enum.of(
    "bottom", -- scrolls to bottom of the view when new element added 
    "focus", -- scrolls so that the focussed element is in the center when new element added, removed or focussed
    "focusLoose" -- as "focus", but only moves when the focussed element is outside the middle half of the screen
)
local TaskKind <const> = util.enum.of(
    "scroll", -- animates the scrolling of the view
    "callback" -- external callback to be executed on update
)
local scrollDurationMsDefault <const> = 200
local playdateScreenW <const> = 400
local playdateScreenH <const> = 240

class "ScrollViewElement" {
    public {
        height = 0,

        __construct = function(self, args)
            args = args or {}
            self.height = typeGuard('number', args.height or 0)
        end,

        update = function(self, rect)
            gfx.drawRoundRect(rect, 5)
            gfx.drawTextInRect("Placeholder ScrollViewElement. Extend and override update()", rect, nil, nil, kTextAlignment.center)
        end,

        onFocus = function(self)
        end,

        onUnfocus = function(self)
        end,
    },
}

class "ScrollView" {
    public {
        __construct = function(self, args)
            args = args or {}
            
            if args.follow ~= nil then Follow:guard(args.follow) end
            self.follow = args.follow
            self.viewport = typeGuard('userdata', args.viewport or geom.rect.new(0, 0, playdateScreenW, playdateScreenH))
            self.padding = typeGuard('userdata', args.padding or geom.vector2D.new(0, 0))
            self.backgroundNineSlice = args.backgroundNineSlice or nil
            self.backgroundColor = args.backgroundColor or nil
            self.movedCallback = typeGuard('function', args.movedCallback or (function() end))
            self.minScroll = typeGuard('number', args.minScroll or 0)

            self.taskQueue = TaskQueue.new()
            self.img = gfx.image.new(self.viewport.width, self.viewport.height)
            self.height = self.padding.y
        end,

        pushBottom = function(self, element)
            typeGuard("ScrollViewElement", element)
            
            table.insert(self.elements, element)
            self.height += element.height + self.padding.y

            if self.follow == "bottom" then
                self:enqueueScrollToBottom() 
            elseif self.follow == "focus" or self.follow == "focusLoose" then
                self:enqueueScrollToFocus()
            end
        end,

        popBottom = function(self)
            local removed = table.remove(self.elements)
            if removed ~= nil then
                self.height -= removed.height + self.padding.y
            end

            if self.follow == "bottom" then
                self:enqueueScrollToBottom() 
            elseif self.follow == "focus" or self.follow == "focusLoose" then
                self:enqueueScrollToFocus()
            end

            self:mightHaveMovedElements()
        end,

        getFocusElement = function(self)
            return self.focusElement
        end,

        -- get bounding rect for given element relative to the screen (may be off-screen)
        -- nil if nil or element not in this ScrollView
        getElementRectOnScreen = function(self, el)
            if el == nil then
                return nil
            end
            
            local exists = false
            local elementTop = -self.scroll + self.padding.y
            for i, element in ipairs(self.elements) do
                if element == el then
                    exists = true
                    break
                end
                elementTop += element.height + self.padding.y
            end
            if not exists then
                return nil
            end
            return geom.rect.new(
                self.padding.x + self.viewport.left, 
                elementTop + self.viewport.top, 
                self:getRowWidth(),
                el.height
            )
        end,

        focus = function(self, elementIndex)
            typeGuard('number', elementIndex)

            -- if selecting off the end of the list, select last in list
            elementIndex = math.min(elementIndex, self:getElementCount())

            if self.focusElement ~= nil then
                self.focusElement:onUnfocus()
            end
            self.focusElement = self.elements[elementIndex]
            if self.focusElement ~= nil then
                self.focusElement:onFocus()
            end

            if self.follow == "focus" or self.follow == "focusLoose" then
                self:enqueueScrollToFocus()
            end
        end,

        -- clamps value between acceptable scroll bounds
        clampScroll = function(self, value)
            local scrollEnd = self.height - self.viewport.height
            local scrollStart = math.min(self.minScroll, scrollEnd)
            if value < scrollStart then
                return scrollStart
            elseif value > scrollEnd then
                return scrollEnd
            else
                return value
            end
        end,

        scrollUp = function(self, px)
            self:scrollDown(-px)
        end,

        scrollDown = function(self, px)
            self:setScroll(self:clampScroll(self.scroll + px))
        end,

        getScroll = function(self)
            return self.scroll
        end,

        setScroll = function(self, scroll)
            typeGuard('number', scroll)
            self.scroll = scroll
            self:mightHaveMovedElements()
        end,

        centerElement = function(self, idx)
            local element = self.elements[idx]
            if element == nil then
                return
            end
            local top = self:elementTop(self.focusElement)
            local target = top - (self.viewport.height - element.height)/2
            self:setScroll(target)
        end,

        -- queues a callback which is guaranteed to be executed after the current active scrolling is complete
        -- no guarantee over exactly when it's called, other than inside the update() function in a future frame
        afterFinishScroll = function(self, f)
            typeGuard('function', f)
            tsk = TaskQueueTask.new{
                kind = 'callback',
                run = function()
                    f()
                    return true
                end,
            }
            self.taskQueue:submit(tsk)
        end,

        update = function(self)
            util.gfx.withImageContext(self.img, function()
                if self.backgroundColor ~= nil then
                    gfx.clear(self.backgroundColor)
                else 
                    gfx.clear(gfx.kColorClear)
                end

                self.taskQueue:update()

                if self.backgroundNineSlice ~= nil then
                    local bgHeight = self.height + (self.viewport.height * 2)
                    self.backgroundNineSlice:drawInRect(0, -self.viewport.height - self.scroll, self.viewport.width, bgHeight)
                end

                local elementTop = -self.scroll + self.padding.y
                for _, element in ipairs(self.elements) do
                    element:update(geom.rect.new(
                        self.padding.x, 
                        elementTop, 
                        self:getRowWidth(), 
                        element.height
                    ))
                    elementTop = elementTop + element.height + self.padding.y
                end
            end)
            self.img:draw(self.viewport.x, self.viewport.y)
        end,

        getElementCount = function(self)
            return #self.elements
        end,

        getElements = function(self)
            local elements = {}
            for _, element in ipairs(self.elements) do
                table.insert(elements, element)
            end
            return elements
        end,

        getRowWidth = function(self)
            return self.viewport.width - 2*self.padding.x
        end,

        getViewportDimensions = function(self)
            return self.viewport.width, self.viewport.height
        end,

        getDimensions = function(self)
            return self.viewport.width, self.height
        end,

        setScrollDurationMs = function(self, d)
            if d == nil then
                d = scrollDurationMsDefault
            end
            self.scrollDurationMs = typeGuard('number', d)
        end,
    },
    private {
        img = null, -- gfx.image
        follow = null, -- nil | "top" | "bottom"
        taskQueue = null, -- TaskQueue
        elements = {},
        height = 0,
        scroll = 0,
        minScroll = 0,
        viewport = null, -- geom.rect
        padding = null, -- geom.vector2D
        backgroundNineSlice = null, -- gfx.nineSlice
        backgroundColor = null, -- gfx.kColor*
        scrollDurationMs = scrollDurationMsDefault,
        focusElement = null, -- ScrollViewElement
        movedCallback = function(self) end,

        elementTop = function(self, e)
            local top = self.padding.y
            for _, element in ipairs(self.elements) do
                if element == e then
                    return top
                end
                top += element.height + self.padding.y
            end
            return 0
        end,

        enqueueScrollTask = function(self, target)
            if self.scrollDurationMs == 0 then
                self:setScroll(target)
                return
            end

            local task = TaskQueueTask.new{
                kind = 'scroll',
                initialState = { 
                    timer = nil,
                },
                run = function(state)
                    if state.timer == nil then
                        state.timer = timer.new(self.scrollDurationMs, self.scroll, target)
                    end
                    self:setScroll(state.timer.value)
                    return state.timer.timeLeft == 0
                end,
            }
            self.taskQueue:cancelTasksOfKind('scroll')
            self.taskQueue:submit(task)
        end,

        enqueueScrollToBottom = function(self)
            self:enqueueScrollTask(self:clampScroll(2 ^ 32))
        end,

        enqueueScrollToFocus = function(self)
            if self.focusElement == nil then
                return
            end
            local top = self:elementTop(self.focusElement)
            local target = top - (self.viewport.height - self.focusElement.height)/2
            if self.follow == 'focusLoose' then
                local screenTop = top - self.scroll
                local lowerScreenBound = self.viewport.height/4
                local upperScreenBound = (3*self.viewport.height/4) - self.focusElement.height
                if screenTop < lowerScreenBound then
                    target = top - lowerScreenBound
                elseif screenTop > upperScreenBound then
                    target = top - upperScreenBound
                else
                    target = self.scroll -- no change.
                end
            end
            self:enqueueScrollTask(target)
        end,

        mightHaveMovedElements = function(self)
            self:movedCallback()
        end,
    },
}
