package org.lodenstone.armada.damageprobabilities;

import java.util.HashMap;

public class DamageProbabilities {

    public static void main(String[] args) {
        var weaponMaxDamage = 10;
        var iterations = 100000;
        var damageDone = new HashMap<Integer, Integer>();

        for (int i = 0; i < iterations; i++) {
            var result = Game.standard(weaponMaxDamage).play();
            damageDone.compute(result.damageDone(), (k, v) -> v == null ? 1 : v + 1);
        }
        damageDone.forEach((dmg, times) -> System.out.printf("%d,%d,%.2f%n", dmg, times, (float)times/iterations));
    }
}
