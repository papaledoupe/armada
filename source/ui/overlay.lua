import "CoreLibs/graphics"
import "CoreLibs/timer"
import "CoreLibs/easing"
import "CoreLibs/nineslice"
local geom <const> = playdate.geometry
local gfx <const> = playdate.graphics
local timer <const> = playdate.timer
import "util/oo"
local valueobject <const> = util.oo.valueobject
local typeGuard <const> = util.oo.typeGuard
local typeGuardElements <const> = util.oo.typeGuardElements
import "util/table"
local hasValue <const> = util.table.hasValue
import "util/enum"
local Enum <const> = util.enum
import "util/set"
local Set <const> = util.set
import "util/fsm"
import "util/gfx"
import "util/string"
import "util/memo"
local memo <const> = util.memo
import "game/state"

local playdateScreenW <const> = 400
local playdateScreenH <const> = 240

local buttonBubbleRounding <const> = 5
local buttonBubblePadding <const> = 5

local messageMargin <const> = 20
local messagePadding <const> = 10
local messageRadius <const> = 10

local ArrowButtons <const> = Enum.of('up', 'down', 'left', 'right')
local MainButtons <const> = Enum.of('a', 'b')
local Buttons <const> = Enum.union(ArrowButtons, MainButtons, Enum.of('crank'))

local function getButtonChar(button)
    Buttons:guard(button)
    if button == 'a' then return 'Ⓐ'
    elseif button == 'b' then return 'Ⓑ'
    elseif button == 'up' then return '⬆️'
    elseif button == 'down' then return '⬇️'
    elseif button == 'left' then return '⬅️'
    elseif button == 'right' then return '➡️'
    elseif button == 'crank' then return '🎣'
    else return '?'
    end
end

local function getButtonChars(buttons)
    typeGuard('table', buttons)
    local text = ''
    if 
        #buttons == 4 
        and hasValue(buttons, 'up') 
        and hasValue(buttons, 'down') 
        and hasValue(buttons, 'left') 
        and hasValue(buttons, 'right') 
    then
        return '✛'
    end 
    for _, button in ipairs(buttons) do
        text = text .. getButtonChar(button)
    end
    return text
end


valueobject "OverlayUIChildAction" {
    label = { type = 'string' },
    button = { 
        type = 'string', 
        validate = function(b) 
            ArrowButtons:guard(b)
            return true
        end
    },
    callback = { 
        type = 'function', 
        default = function() end,
    },
}

class "OverlayUIAction" {
    public {
        -- called when button first down
        callback = function(label, button) end,
        -- called each frame while button held
        repeat_ = function(label, button) end,

        __construct = function(self, args)
            self.label = typeGuard('string', args.label or error('label required'))
            self.children = typeGuardElements('OverlayUIChildAction', args.children or {})
            self.callback = typeGuard('function', args.callback or function() end)
            self.repeat_ = typeGuard('function', args.repeat_ or function() end)

            local buttons = typeGuard('table', args.buttons or {})
            if args.button then
                buttons = {args.button}
            end
            if #buttons == 0 then
                error('at least one button required')
            end
            for _, button in ipairs(buttons) do
                if #self.children > 0 then
                    MainButtons:guard(button)
                else
                    Buttons:guard(button)
                end
                table.insert(self.buttons, button)
            end
        end,

        getLabelText = function(self)
            local text = getButtonChars(self.buttons)
            local actionText = ''
            if #self.children > 0 then
                actionText = 'Hold'
            end
            return text .. ' *' .. (actionText ~= '' and ('(' .. actionText .. ') ') or '') .. self.label .. '*'
        end,
    },
    private {
        getter {
            label = '',
            buttons = {},
            children = {},
        },
    },
}

local cursorOscillateMs = 500
local cursorAreaNineslice <const> = gfx.nineSlice.new('images/area_cursor', 7, 7, 1, 1)

class "OverlayCursor" {
    public {
        static {
            Pos = Enum.of('left', 'top', 'right', 'bottom'),
            Type = Enum.of('area'),
        },

        maxOffset = 0,
        minOffset = 0,

        __construct = function(self, args)
            args = args or {}
            self:setType(args.type or 'area')
            self:setPos(args.pos or 'top')
            self:setRect(args.rect or nil)
            self:setOffset(args.offset or 0)
        end,

        setPos = function(self, pos)
            OverlayCursor.Pos:guard(pos)
            local prev = self.pos
            self.pos = pos
            if prev ~= pos then
                self.dirty = true
            end
        end,

        setType = function(self, type)
            OverlayCursor.Type:guard(type)
            
            if type == 'area' then
                self.img = cursorAreaNineslice
            end
        end,

        setRect = function(self, rect)
            if rect ~= nil then typeGuard('userdata', rect) end
            self.rect = rect
        end,

        setOffset = function(self, min, max)
            min = typeGuard('number', min or 0)
            max = typeGuard('number', max or min)
            self.offsetTimer = playdate.timer.new(cursorOscillateMs, min, max)
            self.offsetTimer.repeats = true
            self.offsetTimer.reverses = true
        end,

        update = function(self)
            if self.rect == nil then
                return 
            end

            -- for debug
            -- util.gfx.withColor(gfx.kColorXOR, function(g)
            --     gfx.drawRect(self.rect)
            -- end)

            local angle = 0
            local x = 0
            local y = 0
            local offset = self.offsetTimer.value

            if self.img.getMinSize == nil then
                -- img is not a nineSlice

                local adjustmentX = 0
                local adjustmentY = 0
                if self.img.width % 2 == 1 then
                    adjustmentX = 1
                end
                if self.img.height % 2 == 1 then
                    adjustmentY = 1
                end

                if self.pos == 'left' then
                    x = self.rect.left - offset
                    y = self.rect.top + adjustmentY + self.rect.height/2
                    angle = -90
                elseif self.pos == 'top' then
                    x = self.rect.left + adjustmentX + self.rect.width/2
                    y = self.rect.top - offset
                    angle = 0
                elseif self.pos == 'right' then
                    x = self.rect.right + offset
                    y = self.rect.top + adjustmentY + self.rect.height/2
                    angle = 90
                elseif self.pos == 'bottom' then
                    x = self.rect.left + adjustmentX + self.rect.width/2
                    y = self.rect.bottom + offset
                    angle = 180
                end
                self.img:drawRotated(x, y, angle)
            else
                -- img is a nineSlice
                local rect = self.rect:insetBy(-offset, -offset)
                self.img:drawInRect(rect)
            end
        end,
    },
    private {
        rect = null, -- geom.rect
        pos = null, -- OverlayCursor.Pos
        img = null, -- gfx.image|gfx.nineSlice
        offsetTimer = null, -- playdate.timer
    },
}

class "OverlayGameInfo" {
    public {
        __construct = function(self, args)
            self.game = typeGuard('GameState', args.game or error('game required'))
        end,

        update = function(self)
            -- if not self.hidden then
            --     self:render():draw(0, 0)
            -- end
        end,

        setHidden = function(self, hidden)
            self.hidden = typeGuard('boolean', hidden or false)
        end,

        render = memo(function(self)
            local text = 'Turn ${1}' % {self.game.turn}

            local textW, textH = gfx.getTextSize(text)
            local rect = geom.rect.new(-buttonBubbleRounding, -buttonBubbleRounding, textW + buttonBubbleRounding + 2*buttonBubblePadding, textH + 2*buttonBubblePadding)
            return util.gfx.withImageContext(gfx.image.new(rect.width, rect.height), function(g)
                util.gfx.withColor(g.kColorBlack, function(g) 
                    g.fillRoundRect(rect, buttonBubbleRounding)
                end)
                util.gfx.withImageDrawMode(gfx.kDrawModeFillWhite, function(g)
                    g.drawText(text, buttonBubblePadding, buttonBubblePadding)
                end)
            end)
        end, {
            extractKeys = function(self)
                return {self.game.turn}
            end,
        }),
    },
    private {
        game = null, -- GameState
        hidden = false,
    }
}

class "OverlayMessage" {
    public {
        setMessage = function(self, msg)
            if msg == nil then
                msg = ''
            end
            self.msg = typeGuard('string', msg)
            self.img = nil
        end,

        update = function(self)
            if self.img == nil then
                self:render()
            end
            self.img:draw(0, 0)
        end,
    }, 
    private {
        msg = '',
        img = null, -- gfx.image|nil

        render = function(self)
            if self.msg == '' then
                self.img = gfx.image.new(1, 1)
                return
            end
            self.img = util.gfx.withImageContext(gfx.image.new(playdateScreenW, playdateScreenH), function(g)
                util.gfx.withPattern('diagonalBlackTransStripe3', function(g)
                    g.fillRect(0, 0, playdateScreenW, playdateScreenH)
                    local w, h = g.getTextSizeForMaxWidth(self.msg, playdateScreenW - ((messageMargin + messagePadding) * 2))
                    h = h + messagePadding * 2
                    w = w + messagePadding * 2
                    local messageRect = geom.rect.new((playdateScreenW - w)/2, (playdateScreenH - h)/2, w, h)
                    util.gfx.withColor(g.kColorBlack, function(g)
                        g.fillRoundRect(messageRect, messageRadius)
                    end)
                    local textRect = messageRect:insetBy(messagePadding, messagePadding)
                    util.gfx.withImageDrawMode(g.kDrawModeFillWhite, function(g)
                        g.drawTextInRect(self.msg, textRect, nil, nil, kTextAlignment.center)
                    end)
                end)
            end)
        end,
    }
}

class "OverlayButtonHint" {
    public {
        static {
            Position = Enum.of('bottomRight', 'topRight'),
        },

        update = function(self)
            if self.img == nil then
                self:render()
            end
            if self.inverted then
                util.gfx.withImageDrawMode(gfx.kDrawModeInverted, function()
                    self.img:drawIgnoringOffset(0, 0)
                end)
            else
                self.img:drawIgnoringOffset(0, 0)
            end
        end,

        configure = function(self, labels, options)
            options = options or {}

            self.inverted = options.inverted or false
            self.position = OverlayButtonHint.Position:guard(options.position or 'bottomRight')
            self.labels = typeGuardElements('OverlayUIAction', labels or {})
            self.img = nil
        end,

        render = function(self)
            local text = ''
            for _, label in ipairs(self.labels) do
                if text ~= '' then
                    text = text .. ' '
                end
                text = text .. ' ' .. label:getLabelText()
            end

            self.img = gfx.image.new(playdateScreenW, playdateScreenH)
            if text == '' then
                return
            end

            util.gfx.withImageContext(self.img, function(g)
                local textW, textH = g.getTextSize(text)
                local textL = 1000
                local textT = 1000
                if self.position == 'bottomRight' then
                    textL = playdateScreenW-textW-buttonBubblePadding/2
                    textT = playdateScreenH-textH-buttonBubblePadding/2
                elseif self.position == 'topRight' then
                    textL = playdateScreenW-textW-buttonBubblePadding/2
                    textT = buttonBubblePadding/2
                end
                local textRect = geom.rect.new(textL, textT, textW, textH)
                local bubbleRect = geom.rect.new(
                    textRect.left - buttonBubblePadding,
                    textRect.top - buttonBubblePadding,
                    textRect.width + 2*buttonBubblePadding + buttonBubbleRounding,
                    textRect.height + 2*buttonBubblePadding + buttonBubbleRounding
                )
                if self.position == 'bottomRight' then
                    bubbleRect.width += buttonBubbleRounding
                    bubbleRect.height += buttonBubbleRounding
                elseif self.position == 'topRight' then
                    bubbleRect.width += buttonBubbleRounding
                    bubbleRect.y -= buttonBubbleRounding
                end
                util.gfx.withColor(g.kColorBlack, function(g) 
                    g.fillRoundRect(bubbleRect, buttonBubbleRounding)
                end)
                util.gfx.withImageDrawMode(g.kDrawModeNXOR, function(g) 
                    g.drawText(text, textRect.left, textRect.top) 
                end)
            end)
        end,
    },
    private {
        position = 'bottomRight', -- Position
        labels = {}, -- OverlayUIAction[]
        img = null, -- gfx.image
        inverted = false,
    }
}

class "OverlayArrowMenu" {
    public {
        __construct = function(self, args)
            args = args or {}
            self:setOptions(args.options)
        end,

        setOptions = function(self, options)
            options = typeGuard('table', options or {})
            self.up = typeGuard('string', options.up or '')
            self.left = typeGuard('string', options.left or '')
            self.down = typeGuard('string', options.down or '')
            self.right = typeGuard('string', options.right or '')
            self.any = self.up ~= '' or self.left ~= '' or self.down ~= '' or self.right ~= ''
            self.img = nil
        end,

        setOptionsFromChildActions = function(self, action)
            typeGuard('OverlayUIAction', action)
            local options = {}
            for _, child in ipairs(action.children) do
                ArrowButtons:guard(child.button)
                local label = child.label
                options[child.button] = label
            end
            self:setOptions(options)
        end,

        update = function(self)
            if self.img == nil then
                self:render()
            end
            self.img:drawIgnoringOffset(0, 0)
        end,

        render = function(self)
            self.img = gfx.image.new(playdateScreenW, playdateScreenH)
            if not self.any then
                return
            end
            util.gfx.withImageContext(self.img, function(g) 
                util.gfx.withPattern('diagonalBlackTransStripe3', function(g)
                    g.fillRect(0, 0, playdateScreenW, playdateScreenH)
                end)

                local upDownRect = geom.rect.new(
                    (playdateScreenW - self.arrowRectWidth)/2, 
                    (playdateScreenH - self.arrowRectHeight)/2, 
                    self.arrowRectWidth, 
                    self.arrowRectHeight
                )
                local leftRightRect = geom.rect.new(
                    (playdateScreenW - self.arrowRectHeight)/2, 
                    (playdateScreenH - self.arrowRectWidth)/2, 
                    self.arrowRectHeight, 
                    self.arrowRectWidth
                )
                util.gfx.withColor(g.kColorBlack, function(g)
                    g.fillRoundRect(upDownRect, self.arrowRectRounding)
                    g.fillRoundRect(leftRightRect, self.arrowRectRounding)
                end)
                util.gfx.withColor(g.kColorWhite, function(g)
                    g.fillRoundRect(upDownRect:insetBy(self.arrowRectBorderInset, self.arrowRectBorderInset), self.arrowRectRounding)
                    g.fillRoundRect(leftRightRect:insetBy(self.arrowRectBorderInset, self.arrowRectBorderInset), self.arrowRectRounding)
                end)

                if self.up ~= '' then
                    local text = '*'..self.up..'*'
                    local w, h = g.getTextSize(text)
                    util.gfx.withColor(g.kColorWhite, function(g)
                        g.fillRoundRect(
                            ((playdateScreenW - w)/2) - self.arrowTextBoxPaddingX, 
                            ((playdateScreenH - h)/2) - self.arrowTextBoxPaddingY - self.arrowTextDistance,
                            w + 2*self.arrowTextBoxPaddingX,
                            h + 2*self.arrowTextBoxPaddingY,
                            self.arrowTextBoxRounding
                        )
                    end)
                    util.gfx.withColor(g.kColorBlack, function(g)
                        g.drawTextAligned(text, playdateScreenW/2, playdateScreenH/2 - self.arrowTextDistance - h/2, kTextAlignment.center)
                    end)
                end

                if self.left ~= '' then
                    local text = '*'..self.left..'*'
                    local w, h = g.getTextSize(text)
                    util.gfx.withColor(g.kColorWhite, function(g)
                        g.fillRoundRect(
                            (playdateScreenW/2) - w - self.arrowTextBoxPaddingX - self.arrowTextDistance, 
                            ((playdateScreenH - h)/2) - self.arrowTextBoxPaddingY,
                            w + 2*self.arrowTextBoxPaddingX,
                            h + 2*self.arrowTextBoxPaddingY,
                            self.arrowTextBoxRounding
                        )
                    end)
                    util.gfx.withColor(g.kColorBlack, function(g)
                        g.drawTextAligned(text, playdateScreenW/2 - self.arrowTextDistance, playdateScreenH/2 - h/2, kTextAlignment.right)
                    end)
                end

                if self.down ~= '' then
                    local text = '*'..self.down..'*'
                    local w, h = g.getTextSize(text)
                    util.gfx.withColor(g.kColorWhite, function(g)
                        g.fillRoundRect(
                            ((playdateScreenW - w)/2) - self.arrowTextBoxPaddingX, 
                            ((playdateScreenH - h)/2) - self.arrowTextBoxPaddingY + self.arrowTextDistance,
                            w + 2*self.arrowTextBoxPaddingX,
                            h + 2*self.arrowTextBoxPaddingY,
                            self.arrowTextBoxRounding
                        )
                    end)
                    util.gfx.withColor(g.kColorBlack, function(g)
                        g.drawTextAligned(text, playdateScreenW/2, playdateScreenH/2 + self.arrowTextDistance - h/2, kTextAlignment.center)
                    end)
                end

                if self.right ~= '' then
                    local text = '*'..self.right..'*'
                    local w, h = g.getTextSize(text)
                    util.gfx.withColor(g.kColorWhite, function(g)
                        g.fillRoundRect(
                            (playdateScreenW/2) - self.arrowTextBoxPaddingX + self.arrowTextDistance, 
                            ((playdateScreenH - h)/2) - self.arrowTextBoxPaddingY,
                            w + 2*self.arrowTextBoxPaddingX,
                            h + 2*self.arrowTextBoxPaddingY,
                            self.arrowTextBoxRounding
                        )
                    end)
                    util.gfx.withColor(g.kColorBlack, function(g)
                        g.drawTextAligned(text, playdateScreenW/2 + self.arrowTextDistance, playdateScreenH/2 - h/2, kTextAlignment.left)
                    end)
                end
            end)
        end,
    },
    private {
        static {
            arrowRectWidth = 33,
            arrowRectHeight = 90,
            arrowRectRounding = 30,
            arrowRectBorderInset = 5,
            arrowTextDistance = 68,
            arrowTextBoxPaddingX = 10,
            arrowTextBoxPaddingY = 5,
            arrowTextBoxRounding = 30,
        },

        img = null, -- gfx.image
        up = '',
        left = '',
        down = '',
        right = '',
        any = false,
    }
}

class "OverlayUI" {
    public {
        __construct = function(self, args)
            args = args or {}
            self.game = typeGuard('GameState', args.game)
            self.gameInfo = OverlayGameInfo.new{game = self.game}
            self.cursor = OverlayCursor.new()
            self.buttonHint = OverlayButtonHint.new()
            self.arrowMenu = OverlayArrowMenu.new()
            self.message = OverlayMessage.new()
            self.actions = {}
            self.heldButtons = Set.ofEnum(Buttons)

            self.fsm = FiniteStateMachine.new{
                start = 'OFF',
                transitions = {
                    StateTransition.new{
                        event = 'enable',
                        from = 'OFF',
                        to = 'ACTIONS'
                    },
                    StateTransition.new{
                        event = 'disable',
                        from = 'ACTIONS',
                        to = 'OFF',
                        callback = function()
                            self:onLeaveActionsState()
                            self:onDisable()
                        end,
                    },
                    StateTransition.new{
                        event = 'disable',
                        from = 'CONTEXT_ACTIONS',
                        to = 'OFF',
                        callback = function()
                            self:setActiveParentAction(nil)
                            self:onDisable()
                        end,
                    },
                    StateTransition.new{
                        event = 'showContext',
                        from = 'ACTIONS',
                        to = 'CONTEXT_ACTIONS',
                        callback = function(trans)
                            self:setActiveParentAction(trans.payload)
                            self:onLeaveActionsState()
                        end,
                    },
                    StateTransition.new{
                        event = 'hideContext',
                        from = 'CONTEXT_ACTIONS',
                        to = 'ACTIONS',
                        callback = function(action)
                            self:setActiveParentAction(nil)
                        end,
                    },
                }
            }

            self:registerInputHandler()
        end,

        enable = function(self, actions, options)
            options = options or {}

            self.gameInfo:setHidden(options.hideGameInfo or false)
            self.buttonHint:configure(actions, options)
            self.actions = typeGuardElements('OverlayUIAction', actions)
            self.fsm:trigger('enable')
        end,

        disable = function(self)
            self.fsm:trigger('disable')
        end,

        -- convenience version of :enable to easily connect standard menu controls
        enableMenu = function(self, menu)
            typeGuard('StackMenu', menu)
            self:enable({
                OverlayUIAction.new{
                    label = 'Select',
                    buttons = {'up', 'down'},
                    callback = function(_, btn)
                        if btn == 'up' then
                            menu:up()
                        elseif btn == 'down' then
                            menu:down()
                        end
                    end,
                },
                OverlayUIAction.new{
                    label = 'Select',
                    button = 'a',
                    callback = function()
                        menu:open()
                    end,
                },
                OverlayUIAction.new{
                    label = 'Back',
                    button = 'b',
                    callback = function()
                        menu:close()
                    end,
                },
            }, 'bottomRight')
        end,

        registerInputHandler = function(self)
            local fsm = self.fsm
            local heldButtons = self.heldButtons
            
            local onActionDown = function(button)
                heldButtons:add(button)
            end
            local onActionUp = function(button)
                heldButtons:remove(button)
            end
            local triggerCallbacksForInput = function(button, properties)
                properties = properties or {}
                for _, action in ipairs(self:getActions()) do
                    for _, actionButton in ipairs(action.buttons) do
                        if actionButton == button then
                            action.callback(action.label, actionButton, properties)
                            if #action.children > 0 then
                                fsm:mustTrigger('showContext', action)
                            end
                            return
                        end
                    end
                end
            end
            local actionHandler = {
                AButtonDown = function()
                    triggerCallbacksForInput('a')
                    onActionDown('a')
                end,
                AButtonUp = function()
                    onActionUp('a')
                end,
                BButtonDown = function()
                    triggerCallbacksForInput('b')
                    onActionDown('b')
                end,
                BButtonUp = function()
                    onActionUp('b')
                end,
                leftButtonDown = function()
                    triggerCallbacksForInput('left')
                    onActionDown('left')
                end,
                leftButtonUp = function()
                    onActionUp('left')
                end,
                upButtonDown = function()
                    triggerCallbacksForInput('up')
                    onActionDown('up')
                end,
                upButtonUp = function()
                    onActionUp('up')
                end,
                rightButtonDown = function()
                    triggerCallbacksForInput('right')
                    onActionDown('right')
                end,
                rightButtonUp = function()
                    onActionUp('right')
                end,
                downButtonDown = function()
                    triggerCallbacksForInput('down')
                    onActionDown('down')
                end,
                downButtonUp = function()
                    onActionUp('down')
                end,
                cranked = function(c, a)
                    triggerCallbacksForInput('crank', {change = c, acceleratedChange = a})
                end,
            }

            local triggerContextActionForButton = function(button)
                for _, child in ipairs(self:getActiveParentAction().children) do
                    if child.button == button then
                        fsm:mustTrigger('hideContext')
                        child.callback(child.label, child.button)
                    end
                end
            end
            local maybeReleaseParentButton = function(button)
                for _, parentButton in ipairs(self:getActiveParentAction().buttons) do
                    if button == parentButton then
                        fsm:mustTrigger('hideContext')
                        return
                    end
                end
            end
            local contextActionHandler = {
                leftButtonDown = function()
                    triggerContextActionForButton('left')
                end,
                upButtonDown = function()
                    triggerContextActionForButton('up')
                end,
                rightButtonDown = function()
                    triggerContextActionForButton('right')
                end,
                downButtonDown = function()
                    triggerContextActionForButton('down')
                end,
                AButtonUp = function()
                    maybeReleaseParentButton('a')
                end,
                BButtonUp = function()
                    maybeReleaseParentButton('b')
                end,
            }

            local nop = function() 
                -- no-op function will swallow the input, preventing it being forwarded to other handlers
            end
            local stateAwareHandler = {}
            setmetatable(stateAwareHandler, {
                __index = function(t, k)
                    if fsm.state == 'ACTIONS' then
                        return actionHandler[k] or nop
                    elseif fsm.state == 'CONTEXT_ACTIONS' then
                        return contextActionHandler[k] or nop
                    else
                        return nil -- all inputs bypass the overlay
                    end
                end
            })
            
            playdate.inputHandlers.push(stateAwareHandler)
        end,

        setMessage = function(self, msg)
            self.message:setMessage(msg)
        end,

        clearMessage = function(self)
            self.message:setMessage('')
        end,

        getActions = function(self)
            return self.actions
        end,

        getActiveParentAction = function(self)
            return self.activeParentAction
        end,

        setActiveParentAction = function(self, a)
            if a ~= nil then typeGuard('OverlayUIAction', a) end
            self.activeParentAction = a

            if a == nil then
                self.buttonHint:configure(self:getActions())
                self.arrowMenu:setOptions{}
            else
                self.buttonHint:configure{OverlayUIAction.new{
                    label = '(Release) Back', 
                    buttons = a.buttons
                }}
                self.arrowMenu:setOptionsFromChildActions(a)
            end
        end,

        hideCursor = function(self)
            self:moveCursor{rect = nil}
        end,

        moveCursor = function(self, args)
            if args.pos then self.cursor:setPos(args.pos) end
            if args.type then self.cursor:setType(args.type) end
            self.cursor:setRect(args.rect)
            if type(args.offset) == 'number' then 
                self.cursor:setOffset(args.offset) 
            elseif type(args.offset) == 'table' then
                self.cursor:setOffset(table.unpack(args.offset)) 
            end
        end,

        update = function(self)
            self:triggerButtonRepeats()
            self.cursor:update()
            self.message:update()
            self.arrowMenu:update()
            self.buttonHint:update()
            self.gameInfo:update()
        end,

        onLeaveActionsState = function(self)
            self.heldButtons:clear()
        end,

        onDisable = function(self)
            self.buttonHint:configure{}
            self.arrowMenu:setOptions{}
            self:hideCursor()
            self.actions = {}
            self.activeParentAction = nil
        end,
    },
    private {
        game = null, -- GameState
        fsm = null, -- FiniteStateMachine
        actions = {}, -- OverlayUIAction[]
        activeParentAction = null, -- OverlayUIAction or nil
        buttonHint = null, -- OverlayButtonHint
        cursor = null, -- OverlayCursor
        arrowMenu = null, -- OverlayArrowMenu
        gameInfo = null, -- OverlayGameInfo
        message = null, -- OverlayMessage
        heldButtons = {}, -- {Button: timer}

        triggerButtonRepeats = function(self)
            for _, action in ipairs(self:getActions()) do
                local active = Set.ofEnum(Buttons)
                for _, actionButton in ipairs(action.buttons) do
                    if self.heldButtons:has(actionButton) then
                        active:add(actionButton)
                    end
                end
                if #active:values() > 0 then
                    action.repeat_(action.label, active)
                end
            end
        end,
    }
}
