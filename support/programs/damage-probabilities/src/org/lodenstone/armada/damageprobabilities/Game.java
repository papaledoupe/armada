package org.lodenstone.armada.damageprobabilities;

import java.util.*;

public class Game {

    public enum Suit { HEARTS, DIAMONDS, SPADES, CLUBS }

    public record Card(Suit suit, String name, int value) {
        public static Card number(Suit suit, int number) {
            return new Card(suit, Integer.toString(number), number);
        }
    }

    public static class Deck {
        private final Deque<Card> cards;

        public Deck(Collection<Card> cards) {
            this.cards = new ArrayDeque<>(cards);
        }

        public synchronized void shuffle() {
            var list = new ArrayList<Card>();
            while (this.cards.peek() != null) {
                list.add(this.cards.pop());
            }
            Collections.shuffle(list);
            list.forEach(this.cards::push);
        }

        public Card draw() {
            return this.cards.pop();
        }

        public static Deck standard() {
            var cards = new ArrayList<Card>();
            for (Suit suit : Suit.values()) {
                for (int i = 2; i <= 10; i++) {
                    cards.add(Card.number(suit, i));
                }
                cards.add(new Card(suit, "Jack", 10));
                cards.add(new Card(suit, "Queen", 10));
                cards.add(new Card(suit, "King", 10));
                cards.add(new Card(suit, "Ace", 11));
            }
            return new Deck(cards);
        }

        public static Deck of(Card... cards) {
            return new Deck(Arrays.asList(cards));
        }
    }

    public record Result(int damageDone, int score, List<Card> drawn) {}

    private static final int MAX_SCORE = 21;

    private final Deck deck;
    private final int maxDamage;

    public static Game standard(int maxDamage) {
        var deck = Deck.standard();
        deck.shuffle();
        return new Game(maxDamage, deck);
    }

    public Game(int maxDamage, Deck deck) {
        this.maxDamage = maxDamage;
        this.deck = deck;
    }

    public Result play() {
        var score = 0;
        var drawn = new ArrayList<Card>();
        while (score < MAX_SCORE && getAppliedDamage(score) == 0) {
            var card = deck.draw();
            drawn.add(card);
            score += card.value();
        }
        return new Result(getAppliedDamage(score), score, drawn);
    }

    private int getAppliedDamage(int score) {
        if (score > MAX_SCORE) {
            return 0;
        }
        return Math.max(0, score - MAX_SCORE + this.maxDamage);
    }
}
