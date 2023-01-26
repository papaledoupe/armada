import 'util/oo'
local typeGuard <const> = util.oo.typeGuard
local typeGuardElements <const> = util.oo.typeGuardElements
local valueobject <const> = util.oo.valueobject
import 'util/table'
import 'util/string'
local Enum <const> = util.enum

valueobject "DamageCard" {
    name = { type = 'string' },
    value = { type = 'number' },
    bustValue = { type = 'number' }, -- value the card has if regular value would cause you to go bust
    suit = { type = 'string', validate = function(s) return DamageCard.Suit:has(s) end },

    computed = {
        str = function(self)
            return '${1} of ${2}' % {self.name, self.suit}
        end,
    },

    static = {
        Suit = Enum.of('hearts', 'diamonds', 'clubs', 'spades'),

        number = function(self, suit, n)
            return DamageCard.new{name = tostring(n), value = n, bustValue = n, suit = suit}
        end,
    }
}

class "DamageDeck" {
    public {
        static {
            standard = function()
                local cards = {}
                for _, suit in ipairs(DamageCard.Suit:getValues()) do
                    for i = 2, 10 do
                        table.insert(cards, DamageCard:number(suit, i))
                    end
                    table.insert(cards, DamageCard.new{name = 'J', value = 10, bustValue = 10, suit = suit})
                    table.insert(cards, DamageCard.new{name = 'Q', value = 10, bustValue = 10, suit = suit})
                    table.insert(cards, DamageCard.new{name = 'K', value = 10, bustValue = 10, suit = suit})
                    table.insert(cards, DamageCard.new{name = 'A', value = 11, bustValue = 1, suit = suit})
                end
                return DamageDeck.new{cards = cards}
            end,
        },

        __construct = function(self, args)
            args = args or {}
            self.cards = typeGuardElements('DamageCard', args.cards or {})
        end,

        shuffle = function(self)
            util.table.shuffle(self.cards)
        end,

        draw = function(self)
            return table.remove(self.cards)
        end,

        getCards = function(self)
            return {table.unpack(self.cards)}
        end,
    },
    private {
        cards = {}, -- DamageCard[]
    }
}
