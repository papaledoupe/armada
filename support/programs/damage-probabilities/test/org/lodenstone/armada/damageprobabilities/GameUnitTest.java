package org.lodenstone.armada.damageprobabilities;

import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.lodenstone.armada.damageprobabilities.Game.Card;
import org.lodenstone.armada.damageprobabilities.Game.Deck;
import org.lodenstone.armada.damageprobabilities.Game.Suit;

import java.util.HashMap;

public class GameUnitTest {

    @Test
    void standardDeckHas52CardsIn4Suits() {
        var suitCounts = new HashMap<Suit, Integer>();
        var deck = Deck.standard();
        deck.shuffle();
        for (int i = 0; i < 52; i++) {
            var card = deck.draw();
            suitCounts.compute(card.suit(), (suit, prev) -> prev == null ? 1 : prev + 1);
        }
        Assertions.assertEquals(suitCounts.get(Suit.SPADES), 13);
        Assertions.assertEquals(suitCounts.get(Suit.CLUBS), 13);
        Assertions.assertEquals(suitCounts.get(Suit.HEARTS), 13);
        Assertions.assertEquals(suitCounts.get(Suit.DIAMONDS), 13);
        Assertions.assertEquals(suitCounts.keySet().size(), 4);
    }

    @Test
    void sticksWhenScoreHighEnoughToDoAnyDamage() {
        var game = new Game(5, Deck.of(
                Card.number(Suit.SPADES, 10),
                Card.number(Suit.SPADES, 5),
                Card.number(Suit.SPADES, 3),
                Card.number(Suit.SPADES, 9)
        ));
        var result = game.play();
        Assertions.assertEquals(result.score(), 18);
        Assertions.assertEquals(result.damageDone(), 2);
    }

    @Test
    void twistsAndBustsWhenScoreNotHighEnoughToDoAnyDamage() {
        var game = new Game(2, Deck.of(
                Card.number(Suit.SPADES, 10),
                Card.number(Suit.SPADES, 5),
                Card.number(Suit.SPADES, 3),
                Card.number(Suit.SPADES, 9)
        ));
        var result = game.play();
        Assertions.assertEquals(result.score(), 27);
        Assertions.assertEquals(result.damageDone(), 0);
    }
}
