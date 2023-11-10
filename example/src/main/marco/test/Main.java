package marco.test;

import java.util.Arrays;

import lombok.extern.java.Log;
import org.apache.commons.math.util.MathUtils;

@Log
public class Main {
    public static void main(String[] args) {
        log.info("Hello, World!");

        System.out.println("Given args: " + Arrays.toString(args));
        System.out.println("CommonsMath TWO_PI: " + MathUtils.TWO_PI);
    }
}
