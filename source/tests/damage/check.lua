local lu <const> = import 'lib/luaunit/luaunit'
import 'damage/check'

TestDamageCheck = {

    testCannotInstantiateWithInvalidDamage = function()
        lu.assertErrorMsgContains('maxDamage must be at least 1', function()
            DamageCheck.new{maxDamage = 0, deck = DamageDeck.new{}}
        end)
    end,

    testDrawWhileNoDamage = function()
        local h6 = DamageCard:number('hearts', 6)
        local h9 = DamageCard:number('hearts', 9)
        local h5 = DamageCard:number('hearts', 5)
        local h4 = DamageCard:number('hearts', 4)
        local check = DamageCheck.new{maxDamage = 5, deck = DamageDeck.new{cards = {h6, h9, h5, h4}}}

        lu.assertEquals(check:currentDamage(), 0)
        lu.assertEquals(check.score, 0)
        lu.assertFalse(check:bust())
        
        lu.assertEquals(check:draw(), {h4, h5, h9})
        lu.assertEquals(check:currentDamage(), 2)
        lu.assertEquals(check.score, 18)
        lu.assertFalse(check:bust())

        lu.assertEquals(check:draw(), {h6})
        lu.assertEquals(check:currentDamage(), 0)
        lu.assertEquals(check.score, 24)
        lu.assertTrue(check:bust())
    end,

    testDamageLevels = function()
        local check = DamageCheck.new{maxDamage = 5, deck = DamageDeck.new{}}

        lu.assertEquals(check:damageLevels(), {[1] = 17, [2] = 18, [3] = 19, [4] = 20, [5] = 21})
    end,

    testBustValue = function()
        local hAce = DamageCard.new{name = 'A', suit = 'hearts', value = 11, bustValue = 1}
        local sAce = DamageCard.new{name = 'A', suit = 'spades', value = 11, bustValue = 1}
        local h8 = DamageCard:number('hearts', 8)

        local check = DamageCheck.new{maxDamage = 5, deck = DamageDeck.new{cards = {h8, hAce, sAce}}}

        local cards, scores = check:draw()
        lu.assertEquals(cards, {sAce, hAce, h8})
        lu.assertEquals(scores, {11, 12, 20})
        lu.assertEquals(check.score, 11 + 1 + 8) -- second ace counted as 1 as it would bust otherwise
        lu.assertFalse(check:bust())
    end,
}
