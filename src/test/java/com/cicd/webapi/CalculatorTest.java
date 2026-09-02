package com.cicd.webapi;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertThrows;


public class CalculatorTest {
    
    @Test
    void testAdd() {
        Calculator calculator = new Calculator();
        assert calculator.add(2, 3) == 5;
        assert calculator.add(-2, -3) == -5;
    }

    // Additional test methods for subtract, multiply, and divide can be added here
    @Test
    void testSubtract() {
        Calculator calculator = new Calculator();
        assert calculator.subtract(5, 3) == 2;

        assert calculator.subtract(-5, 3) == -8;
    }

    // Additional test methods for multiply and divide can be added here
    @Test
    void testMultiply() {
        Calculator calculator = new Calculator();
        assert calculator.multiply(2, 3) == 6;
        assert calculator.multiply(0, 3) == 0;
        assert calculator.multiply(1, -3) == -3;
    }

    @Test
    void testDivide() {
        Calculator calculator = new Calculator();
        assert calculator.divide(10, 2) == 5;

        IllegalArgumentException exception = assertThrows(
            IllegalArgumentException.class,
                () -> calculator.divide(10, 0)
            );

        assert exception.getMessage().equals("Denominator cannot be zero");
        
    }

    // Test agregado (no estaba en el repo del curso): cubre las dos ramas
    // de factorial — caso normal y el error por número negativo.
    @Test
    void testFactorial() {
        Calculator calculator = new Calculator();
        assert calculator.factorial(0) == 1;
        assert calculator.factorial(5) == 120;

        IllegalArgumentException exception = assertThrows(
            IllegalArgumentException.class,
                () -> calculator.factorial(-1)
            );

        assert exception.getMessage().equals("Negative numbers are not allowed");
    }
}
