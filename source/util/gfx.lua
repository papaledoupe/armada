import "CoreLibs/graphics"
import "util/oo"
local typeGuard <const> = util.oo.typeGuard
local pg <const> = playdate.graphics

util = util or {}

util.gfx = {

    -- this is useful: https://dev.playdate.store/tools/gfxp/
    patterns = {
        simpleBlackWhiteDither = {0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55},
        diagonalBlackTransStripe3 = {0x88, 0x44, 0x22, 0x11, 0x88, 0x44, 0x22, 0x11, 119, 187, 221, 238, 119, 187, 221, 238},
        thickWhiteStripe3OnBlack = {0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE},

        -- gfxp patterns
        ['dline-7'] = {0xEE, 0xDD, 0xBB, 0x77, 0xEE, 0xDD, 0xBB, 0x77},

        shade0 = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0},
        shade1 = {0x7F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 128, 0, 0, 0, 0, 0, 0, 0},
        shade2 = {0x7F, 0xFF, 0xFF, 0xFF, 0xF7, 0xFF, 0xFF, 0xFF, 128, 0, 0, 0, 8, 0, 0, 0},
        shade3 = {0x77, 0xFF, 0xFF, 0xFF, 0xF7, 0xFF, 0xFF, 0xFF, 136, 0, 0, 0, 8, 0, 0, 0},
        shade4 = {0x77, 0xFF, 0xFF, 0xFF, 0x77, 0xFF, 0xFF, 0xFF, 136, 0, 0, 0, 136, 0, 0, 0},
        shade5 = {0x77, 0xFF, 0xFD, 0xFF, 0x77, 0xFF, 0xDF, 0xFF, 136, 0, 2, 0, 136, 0, 32, 0},
        shade6 = {0x77, 0xFF, 0xDD, 0xFF, 0x77, 0xFF, 0xDD, 0xFF, 136, 0, 34, 0, 136, 0, 34, 0},
        shade7 = {0x57, 0xFF, 0xDD, 0xFF, 0x77, 0xFF, 0xDD, 0xFF, 168, 0, 34, 0, 136, 0, 34, 0},
        shade8 = {0x57, 0xFF, 0x55, 0xFF, 0x57, 0xFF, 0xDD, 0xFF, 168, 0, 170, 0, 168, 0, 34, 0},
        shade9 = {0x55, 0xFF, 0x55, 0xFF, 0x55, 0xFF, 0x55, 0xFF, 170, 0, 170, 0, 170, 0, 170, 0},
        shade10 = {0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 170, 85, 170, 85, 170, 85, 170, 85},
    },

    withColor = function(color, f)
        typeGuard('function', f)

        local prev = pg.getColor()
        pg.setColor(color)
        f(pg)
        if type(prev) == 'table' then
            -- was a pattern rather than color
            pg.setPattern(prev)
        else
            pg.setColor(prev)
        end
    end,

    withImageDrawMode = function(mode, f)
        typeGuard('function', f)

        local prev = pg.getImageDrawMode()
        pg.setImageDrawMode(mode)
        f(pg)
        pg.setImageDrawMode(prev)
    end,

    withImageContext = function(img, f)
        typeGuard('function', f)

        pg.pushContext(img)
        f(pg, img)
        pg.popContext(img)
        return img
    end,

    -- p is a string (key of util.gfx.patterns) or custom pattern table
    withPattern = function(p, f)
        if type(p) == 'string' then
            local name = p
            p = util.gfx.patterns[name]
            if p == nil then
                error('no such pattern '..name)
            end
        end
        typeGuard('table', p)
        typeGuard('function', f)

        local color = pg.getColor()
        pg.setPattern(p)
        f(pg)
        pg.setColor(color)
    end,

    withShade = function(level, f)
        typeGuard('number', level)
        util.gfx.withPattern(util.gfx.patterns['shade'..level] or util.gfx.patterns.shade10, f)
    end,

    getShadeFromTimer = function(startShade, finishShade, t)
        typeGuard('number', startShade)
        typeGuard('number', finishShade)
        local completion = (t.value - t.startValue) / (t.endValue - t.startValue)
        return math.floor((startShade + completion * (finishShade - startShade)) + 0.5) -- approximate rounding
    end,

    withLineWidth = function(w, f)
        typeGuard('number', w)
        typeGuard('function', f)

        local prev = pg.getLineWidth()
        pg.setLineWidth(w)
        f(pg)
        pg.setLineWidth(prev)
    end,

    withDrawOffset = function(x, y, f)
        typeGuard('function', f)
        typeGuard('number', x)
        typeGuard('number', y)

        local prevX, prevY = pg.getDrawOffset()
        pg.setDrawOffset(x, y)
        f(pg)
        pg.setDrawOffset(prevX, prevY)
    end,
}
