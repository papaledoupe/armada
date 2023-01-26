local lu <const> = import 'lib/luaunit/luaunit'
import 'damage/deck'
import 'util/set'
local Set <const> = util.set

TestDamageDeck = {

    testCardConstructors = function()
        local c = DamageCard:number('hearts', 5)
        lu.assertEquals(c.value, 5)
        lu.assertEquals(c.bustValue, 5)
        lu.assertEquals(c.str, '5 of hearts')
    end,

    testDefaultDeckContents = function()
        local deck = DamageDeck:standard()
        local bySuit = {}
        local strSet = Set.ofType('string')
        local cards = deck:getCards()

        lu.assertEquals(#cards, 52)

        for _, card in ipairs(cards) do
            if bySuit[card.suit] == nil then
                bySuit[card.suit] = {}
            end
            table.insert(bySuit[card.suit], card)
            strSet:add(card.str)
        end

        lu.assertEquals(#bySuit.hearts, 13)
        lu.assertEquals(#bySuit.diamonds, 13)
        lu.assertEquals(#bySuit.clubs, 13)
        lu.assertEquals(#bySuit.spades, 13)
        lu.assertEquals(#strSet:values(), 52)
    end,

    testDeckDraw = function()
        local deck = DamageDeck.new{cards = {
            DamageCard:number('hearts', 3),
            DamageCard:number('hearts', 9),
        }}

        lu.assertEquals(deck:draw().str, DamageCard:number('hearts', 9).str) -- note reverse order
        lu.assertEquals(deck:draw().str, DamageCard:number('hearts', 3).str)
        lu.assertNil(deck:draw())
    end,

    testShuffledDefaultDeckHasSameContents = function()
        local deck = DamageDeck:standard()
        deck:shuffle()
        
        local bySuit = {}
        local strSet = Set.ofType('string')
        local cards = deck:getCards()

        lu.assertEquals(#cards, 52)

        for _, card in ipairs(cards) do
            if bySuit[card.suit] == nil then
                bySuit[card.suit] = {}
            end
            table.insert(bySuit[card.suit], card)
            strSet:add(card.str)
        end

        lu.assertEquals(#bySuit.hearts, 13)
        lu.assertEquals(#bySuit.diamonds, 13)
        lu.assertEquals(#bySuit.clubs, 13)
        lu.assertEquals(#bySuit.spades, 13)
        lu.assertEquals(#strSet:values(), 52)
    end,
}
