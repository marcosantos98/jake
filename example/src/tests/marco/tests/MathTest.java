package marco.tests;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

import marco.math.Sum;

public class MathTest {

    @Test
    public void sum() {
        assertEquals("34+35=69", 69, Sum.add(34, 35));
    }
}