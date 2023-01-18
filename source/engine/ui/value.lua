import "CoreLibs/graphics"
import 'util/oo'
import 'util/gfx'
import 'util/enum'
local typeGuard <const> = util.oo.typeGuard
local gfx <const> = playdate.graphics
local geom <const> = playdate.geometry

local outerRounding = 3
local labelPaddingX = 5
local labelPaddingY = 4
local valueMargin = 2
local valuePadding = 2

class "UIValue" {
    public {
        static {
            defaultWidth = 150,

            Scheme = util.enum.of('blackOnWhite', 'whiteOnBlack'),
            defaultScheme = 'blackOnWhite',
        },

        __construct = function(self, args)
            args = args or {}
            self.label = typeGuard('string', args.label or error('label required'))
            self.offset = typeGuard('userdata', args.offset or geom.point.new(0, 0))
            self.width = typeGuard('number', args.width or UIValue.defaultWidth)
            self.scheme = UIValue.Scheme:guard(args.scheme or UIValue.defaultScheme)
            self:updateValue(args.value or '')
        end,

        updateValue = function(self, value)
            self.value = tostring(value)
            self.img = nil
        end,

        update = function(self)
            if self.img == nil then
                self:render()
            end
            self.img:draw(self.offset.x, self.offset.y)
        end,

        -- not known until render called
        getHeight = function(self)
            return self.height
        end,

        render = function(self)
            self.height = gfx.getFont():getHeight() + labelPaddingY * 2
            self.img = gfx.image.new(self.width, self.height)

            util.gfx.withImageContext(self.img, function(g)
                local outerColor = g.kColorBlack
                local innerColor = g.kColorWhite
                if self.scheme == 'whiteOnBlack' then
                    outerColor = g.kColorWhite
                    innerColor = g.kColorBlack
                end

                local labelText = '*'..self.label..'*'
                local labelTextWidth, _ = g.getTextSize(labelText)
                local labelWidth = labelTextWidth + labelPaddingX * 2

                util.gfx.withColor(outerColor, function(g)
                    g.fillRoundRect(0, 0, self.width, self.height, outerRounding)
                    util.gfx.withImageDrawMode(g.kDrawModeFillWhite, function(g)
                        g.drawText(labelText, labelPaddingX, labelPaddingY)
                    end)
                    local valueRect = geom.rect.new(labelWidth, valueMargin, self.width - labelWidth - valueMargin, self.height - valueMargin * 2)
                    util.gfx.withColor(innerColor, function(g)
                        g.fillRect(labelWidth, valueMargin, self.width - labelWidth - valueMargin, self.height - valueMargin * 2)
                    end)
                    g.drawTextInRect(self.value, valueRect:insetBy(valuePadding, valuePadding), nil, nil, kTextAlignment.right)
                end)
            end)
        end,
    },
    private {
        label = '',
        value = '',
        width = 0,
        height = 0, -- unknown until draw
        offset = null, -- geom.point
        img = null, -- gfx.image
        padding = 0,
        rounding = 0,
    },
}