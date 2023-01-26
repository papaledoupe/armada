import 'damage/deck'
import 'util/oo'
local typeGuard <const> = util.oo.typeGuard
import 'util/memo'
local memo <const> = util.memo

class "DamageCheck" {
    public {
        __construct = function(self, args)
            args = args or {}
            self.deck = typeGuard('DamageDeck', args.deck or DamageDeck:standard())
            self.maxDamage = typeGuard('number', args.maxDamage or error('maxDamage required'))
            if self.maxDamage < 1 then error 'maxDamage must be at least 1' end
            self.maxScore = typeGuard('number', args.maxScore or 21)

            if args.deck == nil then
                self.deck:shuffle() -- if defaulted to standard deck, shuffle it.
            end
        end,

        -- will draw cards while there is no choice (i.e., no damage applied so no point not drawing more) and not bust
        -- return DamageCard[], number[] (individal score steps after each draw applied)
        draw = function(self)
            local drawn = {}
            local scores = {}

            repeat
                local card = self.deck:draw()
                if card == nil then
                    error 'no more cards to draw'
                end
                table.insert(drawn, card)
                if self.score + card.value > self.maxScore then
                    self.score = self.score + card.bustValue
                else
                    self.score = self.score + card.value
                end
                table.insert(scores, self.score)
            until self:bust() or self:currentDamage() > 0

            return drawn, scores
        end,

        bust = function(self)
            return self.score > self.maxScore
        end,

        currentDamage = function(self)
            if self:bust() then
                return 0
            end
            return self:calcDamage(self.score)
        end,

        -- returns table where key = possible dmg amounts and value = required score
        -- (note: since this is a continous sequence starting from 1, this is therefore a standard array-style table)
        damageLevels = memo(function(self)
            local lvls = {}
            for i = self.maxScore - self.maxDamage + 1, self.maxScore do
                lvls[self:calcDamage(i)] = i
            end
            return lvls
        end),
    },
    private {
        getter {
            maxDamage = 0,
            maxScore = 0,
            score = 0,
        },
        deck = null, -- DamageDeck

        calcDamage = function(self, score)
            return math.max(0, score - self.maxScore + self.maxDamage)
        end,
    }
}
