import 'CoreLibs/graphics'
import 'util/gfx'
local gfx <const> = playdate.graphics
local geom <const> = playdate.geometry
import 'util/oo'
local typeGuard <const> = util.oo.typeGuard
local typeGuardElements <const> = util.oo.typeGuardElements
import 'engine/ui/stackview'
import 'engine/ui/scrollview'

local menuBackgroundColor <const> = gfx.kColorWhite
local menuItemPadding <const> = 8

class "StackMenuItem" {
    public {
        label = '', -- the label on the menu element
        title = '', -- displayed at the top of its list of children (defaults to label)
        back = 0, -- if >0, selecting this item prompts the menu back action N times after callback called
        selectable = true,
        close = false, -- if true, selecting this item prompts the entire menu to be closed after callback called
        children = null, -- nil, or function returning []StackMenuItem (function will be called each time the menu is on top, allowing variation in contents)
        callback = null, -- called when selected (in addition to children being opened, if any)
        drawFooter = function(self, width) return nil end, -- return an image to display as footer of the row

        __construct = function(self, args)
            args = args or {}
            self.label = typeGuard('string', args.label or error('label required'))
            self.title = typeGuard('string', args.title or self.label)
            
            if args.back == true then
                self.back = 1
            elseif args.back == false then
                self.back = 0
            else
                self.back = typeGuard('number', args.back or 0)
            end
            
            self.close = typeGuard('boolean', args.close or false)
            
            if type(args.children) == 'function' then
                self.children = args.children
            else
                local children = typeGuardElements('StackMenuItem', args.children or {})
                if #children > 0 then
                    self.children = function() return children end
                end
            end

            self.callback = typeGuard('function', args.callback or function() end)

            if self.back > 0 and self.close then
                error 'invalid arguments - combination of back and close'
            end
            if self.back > 0 and self.children ~= nil then
                error 'invalid arguments - back item cannot have children'
            end
            if self.close and self.children ~= nil then
                error 'invalid arguments - close item cannot have children'
            end

            if args.selectable == false then
                if args.callback ~= nil or self.back > 0 or self.close then
                    error 'invalid arguments - non selectable item should not have any of: callback, back, close'
                end
                self.selectable = false
            else
                self.selectable = true
            end

            self.drawFooter = typeGuard('function', args.drawFooter or function(self, width) return nil end)
        end,
    }
}

class "StackMenu" {
    public {
        __construct = function(self, args)
            args = args or {}

            if type(args.items) == 'function' then
                self.items = args.items
            elseif args.items ~= nil then
                local items = typeGuardElements('StackMenuItem', args.items or {})
                if #items > 0 then
                    self.items = function() return items end
                end
            end

            self.onClose = typeGuard('function', args.onClose or function() end)

            local title = nil
            if args.title ~= nil then
                title = typeGuard('string', args.title)
            end
            self.view = StackView.new{
                rect = args.rect,
                start = self:createStackElement(title, self.items),
            }
        end,

        update = function(self)
            self.view:update()
        end,

        -- select previous menu item
        up = function(self)
            self.view:top():up()
        end,

        -- select next menu item
        down = function(self)
            self.view:top():down()
        end,

        -- open current menu item
        open = function(self)
            local top = self.view:top()
            local item = top:getCurrentItem()
            if item == nil then
                return
            end
            top:afterFinishScroll(function()
                if item.children ~= nil then
                    self.view:push(self:createStackElement(item.title, item.children))
                end
                item:callback()
                if item.close then
                    self.onClose()
                end
                if item.back > 0 then
                    self:close(item.back)
                end
            end)
        end,

        -- close current menu n times
        close = function(self, n)
            self.view:pop{n = n, callbackOnEmpty = self.onClose}
        end,
    },
    private {
        view = null, -- StackView
        items = null, -- nil, or function returning []StackMenuItem
        onClose = function() end, -- called when last menu closed

        createStackElement = function(self, title, items)
            return StackMenuElement.new{title = title, itemFactory = items}
        end,
    },
}

-- internal classes:

class "StackMenuElement" extends "StackViewElement" {
    public {
        __construct = function(self, args)
            args = args or {}
            
            self.itemFactory = typeGuard('function', args.itemFactory or error('itemFactory required'))
            if args.title ~= nil then
                self.title = typeGuard('string', args.title)
            end
            self.cursor = 0
        end,

        afterFinishScroll = function(self, f)
            self.scrollView:afterFinishScroll(f)
        end,

        getCurrentItem = function(self)
            if self.scrollView == nil or self.scrollView:getFocusElement() == nil then
                return nil
            end
            return self.scrollView:getFocusElement().item
        end,

        up = function(self)
            local cursor = self.cursor
            while true do
                cursor = cursor - 1
                if cursor == 0 then
                    return
                end
                local prev = self.scrollView:getElements()[cursor]
                if prev == nil then
                    return
                end
                if prev.item.selectable then
                    break
                end
            end
            self.cursor = cursor
            self.scrollView:focus(self.cursor)
        end,

        down = function(self)
            local cursor = self.cursor
            local length = #self.scrollView:getElements()
            while true do
                cursor = cursor + 1
                if cursor > length then
                    return
                end
                local nxt = self.scrollView:getElements()[cursor]
                if nxt.item.selectable then
                    break
                end
            end
            self.cursor = cursor
            self.scrollView:focus(self.cursor)
        end,

        update = function(self, size)
            if self.scrollView == nil then
                self.scrollView = ScrollView.new{
                    follow = 'focus',
                    viewport = geom.rect.new(0, 0, size.width, size.height),
                    backgroundColor = menuBackgroundColor,
                }
                if self.title ~= nil then
                    self.scrollView:pushBottom(StackMenuItemScrollViewElement.new{
                        bold = true,
                        item = StackMenuItem.new{
                            label = self.title,
                            selectable = false,
                        },
                        width = size.width,
                    })
                end
                for _, item in ipairs(self.itemFactory()) do
                    self.scrollView:pushBottom(StackMenuItemScrollViewElement.new{
                        item = item,
                        width = size.width,
                    })
                end
                self.scrollView:setScrollDurationMs(0)
                if self.cursor == 0 then
                    self.scrollView:centerElement(1)
                    self:down()
                else
                    local current = self.scrollView:getElements()[self.cursor]
                    if current == nil or not current.item.selectable then
                        self:up()
                        local current = self.scrollView:getElements()[self.cursor]
                        if current == nil or not current.item.selectable then
                            self:down()
                        end
                    end
                    if self.scrollView:getElements()[self.cursor] ~= nil then
                        self.scrollView:focus(self.cursor)
                    else
                        self.cursor = 0
                        self.scrollView:centerElement(1)
                    end
                end
                self.scrollView:setScrollDurationMs()
            end
            self.scrollView:update()
        end,

        snapshot = function(self)
            local w, h = self.scrollView:getViewportDimensions()
            local ss = util.gfx.withImageContext(gfx.image.new(w, h), function() 
                self.scrollView:update()
            end)
            -- nilling the scroll view will cause it to be re-rendered from scratch when next shown,
            -- the items might have changed
            self.scrollView = nil
            return ss
        end,
    },
    private {
        cursor = 0, -- only 0 if no selectable options, other wise will be pinned between 1 and N
        title = null, -- string|nil
        itemFactory = function() return {} end, -- function returning []StackMenuItem
        scrollView = null, -- ScrollView
    }
}

class "StackMenuItemScrollViewElement" extends "ScrollViewElement" {
    public {
        __construct = function(self, args)
            args = args or {}
            self.item = typeGuard('StackMenuItem', args.item or error('item required'))
            self.bold = typeGuard('boolean', args.bold or false)
            local width = typeGuard('number', args.width or error('width required'))
            self:render(width)
            self.ScrollViewElement{height = self.img.height}
        end,

        update = function(self, rect)
            util.gfx.withImageDrawMode(self.focussed and gfx.kDrawModeInverted or gfx.kDrawModeCopy, function()
                self.img:draw(rect.left, rect.top)
            end)
        end,

        onFocus = function(self)
            if not self.item.selectable then
                error 'cannot focus unselectable item'
            end
            self.focussed = true
        end,

        onUnfocus = function(self)
            if not self.item.selectable then
                error 'cannot unfocus unselectable item'
            end
            self.focussed = false
        end,
    },
    private {
        img = null, -- gfx.image

        getter {
            item = null, -- StackMenuItem
            focussed = false,
            bold = false,
        },

        render = function(self, width)
            local text = self.item.label
            if self.bold then
                text = '*'..text..'*'
            end
            local bodyHeight = 0
            -- determine height with prototype text draw using pd sdk to handle wrapping for us
            util.gfx.withImageContext(gfx.image.new(1, 1), function(g) 
                local textRect = geom.rect.new(0, 0, width - menuItemPadding*2, 1000)
                local _, textH = g.drawTextInRect(text, textRect, nil, nil, kTextAlignment.left)
                bodyHeight = textH + menuItemPadding*2
            end)

            local height = bodyHeight
            local footer = self.item:drawFooter(width)
            if footer ~= nil then
                height = height + footer.height
            end

            self.img = util.gfx.withImageContext(gfx.image.new(width, height, gfx.kColorWhite), function(g)
                local imgRect = geom.rect.new(0, 0, width, height)
                local textRect = imgRect:insetBy(menuItemPadding, menuItemPadding)
                g.drawTextInRect(text, textRect, nil, nil, kTextAlignment.left)
                if footer ~= nil then
                    footer:draw(0, bodyHeight)
                end
            end)
        end,
    }
}
