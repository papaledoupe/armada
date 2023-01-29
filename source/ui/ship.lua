import 'ship/ship'
import 'CoreLibs/graphics'
local gfx <const> = playdate.graphics
import 'util/memo'
local memo <const> = util.memo
import 'util/oo'
local typeGuard <const> = util.oo.typeGuard
import 'util/math'
local clamp <const> = util.math.clamp

local playdateScreenW <const> = 400
local playdateScreenH <const> = 240

local sdImage <const> = gfx.image.new('images/ship_stardestroyer')

local sponsonRadius <const> = 5

local projectionStepsPerMeter <const> = 0.1
local projectionDotRadius <const> = 2
local projectionMinSteps <const> = 2
local projectionMaxSteps <const> = 20

class "ShipUI" {
    public {
        __construct = function(self, args)
            args = args or {}
            self.ship = typeGuard('Ship', args.ship)

            self.shipImg = sdImage

            self.sponsonImgs = {}
            self.arcImgs = {}
            for _, sponson in ipairs(self.ship.sponsons) do
                table.insert(self.sponsonImgs, self:sponsonRenderer(sponson))
                table.insert(self.arcImgs, self:arcRenderer(sponson))
            end
        end,

        draw = function(self)
            self.shipImg:drawRotated(self.ship.movement.x, self.ship.movement.y, self.ship.movement.bearing)
            
            for i, sponson in ipairs(self.ship.sponsons) do
                local x, y = self.ship:getSponsonPosition(i)
                local active = self.activeSponson == i
                local currentOrientation = (sponson.orientation + self.ship.movement.bearing)
                local sponsonImg = self.sponsonImgs[i]()
                local arcImg = self.arcImgs[i]()
                util.gfx.withImageContext(gfx.image.new(arcImg.width, arcImg.height), function(g)
                    arcImg:drawFaded(0, 0, 0.5, g.image.kDitherTypeDiagonalLine)
                end):drawRotated(x, y, currentOrientation)
                if active then
                    arcImg:drawRotated(x, y, self.activeSponsonOrientation)
                    sponsonImg:drawRotated(x, y, self.activeSponsonOrientation)
                else
                    sponsonImg:drawRotated(x, y, currentOrientation)
                end
            end

            if self.projectionImg ~= nil then
                util.gfx.withImageDrawMode(gfx.kDrawModeNXOR, function(g)
                    util.gfx.withDrawOffset(0, 0, function(g)
                        self.projectionImg:draw(0, 0)
                    end)
                end)
            end
        end,

        clearProjection = function(self)
            self.projectionImg = nil
        end,

        renderProjection = memo(function(self, targetVelocity, targetBearing)
            local avgVelocity = ((targetVelocity + self.ship.movement.velocity)/2)
            local approxDistance = avgVelocity * ShipCommand.durationSeconds
            local steps = clamp(math.ceil(approxDistance * projectionStepsPerMeter), projectionMinSteps, projectionMaxSteps)
            self.projectionImg = util.gfx.withImageContext(gfx.image.new(playdateScreenW, playdateScreenH), function(g, img)
                g.fillCircleAtPoint(img.width/2, img.height/2, projectionDotRadius)
                for _, projection in ipairs(self.ship:projectMovement{targetVelocity = targetVelocity, targetBearing = targetBearing, steps = steps}) do
                    local x, y = img.width/2 + projection.x - self.ship.movement.x, img.height/2 + projection.y - self.ship.movement.y
                    g.fillCircleAtPoint(x, y, projectionDotRadius)
                end
            end)
        end),

        activateSponson = function(self, idx, orientation)
            self.activeSponson = idx
            self.activeSponsonOrientation = orientation
        end,

        deactivateSponson = function(self)
            self.activeSponson = 0
            self.activeSponsonOrientation = 0
        end,
    },
    private {
        getter {
            ship = null, -- Ship
        },
        cmdSelection = null, -- ShipCommand|nil
        shipImg = null, -- gfx.image
        sponsonImgs = {}, -- (function: gfx.image)[]
        arcImgs = {}, -- (function: gfx.image)[]
        projectionImg = null, -- gfx.image

        activeSponson = 0,
        activeSponsonOrientation = 0,

        sponsonRenderer = function(self, sponson)
            return memo(function()
                return util.gfx.withImageContext(gfx.image.new(sponsonRadius*2, sponsonRadius*2), function(g)
                    util.gfx.withColor(g.kColorWhite, function(g)
                        g.fillCircleAtPoint(sponsonRadius, sponsonRadius, sponsonRadius)
                    end)
                    g.drawCircleAtPoint(sponsonRadius, sponsonRadius, sponsonRadius)
                    g.drawLine(sponsonRadius, 0, sponsonRadius, sponsonRadius)
                end)
            end)
        end,

        arcRenderer = function(self, sponson)
            return memo(function()
                local maxRange = sponson:getMaxRange()
                return util.gfx.withImageContext(gfx.image.new(maxRange*2, maxRange*2), function(g, img)
                    util.gfx.withDrawOffset(img.width/2, img.height/2, function(g)
                        for range, dmg in pairs(sponson.ranges) do
                            local min, max = -sponson.spread/2, sponson.spread/2
                            g.drawArc(0, 0, range, min, max)
                            g.drawLine(0, 0, range * math.sin(math.rad(min)), -range * math.cos(math.rad(min)))
                            g.drawLine(0, 0, range * math.sin(math.rad(max)), -range * math.cos(math.rad(max)))
                            --g.drawTextAligned(tostring(dmg), (range-10) * math.sin(math.rad((max + min)/2)), -(range-10) * math.cos(math.rad((max + min)/2)), kTextAlignment.center)
                        end
                    end)
                end)
            end)
        end,
    }
}
