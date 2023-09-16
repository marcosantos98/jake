package marco.test;

import java.util.Arrays;

import marco.math.Sum;

public class Main {
    public static void main(String[] args) {
        System.out.println("Hello, World!");
        System.out.println("Given args: " + Arrays.toString(args));
        System.out.printf("34 + 35 = %d\n", Sum.add(34, 35));
    }
}