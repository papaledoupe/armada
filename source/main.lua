import "CoreLibs/graphics"
local gfx <const> = playdate.graphics
import "CoreLibs/timer"
import "util/deltatime"
import 'ui/stack'
import 'game/state'

local game = GameState.new{
    ships = {
        Ship.new{
            stats = ShipStats:example(),
            x = 100,
            y = 100,
            bearing = 45,
            velocity = 20,
            sponsons = {
                SponsonWeapon.new{
                    minOrientation = -45,
                    maxOrientation = 45,
                    spread = 45,
                    range = 50,
                    mountPosY = -20,
                },
            },
        },
        Ship.new{
            stats = ShipStats:example(),
            x = 200,
            y = 150,
            bearing = 135,
            velocity = 20,
        },
    }
}
-- local ui = UIStackController.new{game = game}

-- TEMP
import 'ui/damage'
local overlay = OverlayUI.new{game = game}
local ui = DamageCheckUI.new{
    overlay = overlay,
    check = DamageCheck.new{maxDamage = 10},
    onComplete = function(check)
        print('score ', check.score, 'damage', check:currentDamage())
    end,
}
-- TEMP END

function playdate.update()
    gfx.clear(gfx.kColorWhite)

    DeltaTime.update()
    playdate.timer.updateTimers()
 
    ui:update()
    overlay:update()
end
