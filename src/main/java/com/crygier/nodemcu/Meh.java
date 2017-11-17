package com.crygier.nodemcu;

import java.io.IOException;
        import java.util.Stack;

public class Meh {
    public static void main(String[] args) throws IllegalAccessException, ClassNotFoundException, InstantiationException, IOException {
        getNGE(new int[]{3, 2, 4, 6, 3, 2, 0, 100});
    }

    public static void getNGE(int[] a) {
        Stack<Integer> s = new Stack<Integer>();
        s.push(a[0]);

        for (int i = 1; i < a.length; i++) {
            System.out.println("- " + a[i] + " <? " + s.peek());
            if (s.peek() != null) {
                while (true) {
                    if (s.size() == 0 || s.peek() > a[i]) {
                        break;
                    }
                    System.out.println(s.pop() + ":" + a[i]);
                }
            }
            s.push(a[i]);
        }
        while (s.size() != 0) {
            System.out.println(s.pop() + ":" + -1);
        }
    }
}
