import 'util/string'
import 'util/oo'
local typeGuardElements <const> = util.oo.typeGuardElements
import 'util/enum'
local Enum <const> = util.enum
import 'util/fsm'
import 'ship/ship'

class "GameState" {
    public {
        __construct = function(self, args)
            args = args or {}
            self.ships = typeGuardElements('Ship', args.ships or {})
        end,
    },
    private {
        getter {
            ships = {}, -- []Ship
        },
    },
}
