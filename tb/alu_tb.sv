`timescale 1ns / 1ps
import riscv_pkg::*;

module alu_tb;  // no ports becaue this is the environment (nothign to I/O)

    word_t   a;
    word_t   b;
    alu_op_t alu_op;
    word_t   result;
    logic    zero;

    // Instantiate the device under test (dut)
    alu dut (
        .a(a),           // Connect 'a' wire to ALU's 'a' pin
        .b(b),           // Connect 'b' wire to ALU's 'b' pin
        .alu_op(alu_op), 
        .result(result), 
        .zero(zero)
    );

    initial begin

        // --- Record Results ---
        $dumpfile("build/alu_waves.vcd"); // Creates the data file
        $dumpvars(0, alu_tb);         // Record everything (0) in this module (alu_tb)

        // --- TEST 1: Simple Addition ---
        a = 32'd10;      // Set 'a' to 10
        b = 32'd5;       // Set 'b' to 5
        alu_op = ALU_ADD; // Set mode to ADD
        #10;             // WAIT 10ns for electricity to travel through gates
        $display("Test 1 (Add): %0d + %0d = %0d", a, b, result);

        // --- TEST 2: Subtraction to Zero ---
        a = 32'd20;
        b = 32'd20;
        alu_op = ALU_SUB;
        #10;             // WAIT 10ns
        $display("Test 2 (Sub): %0d - %0d = %0d (Zero Flag: %b)", a, b, result, zero);

        $finish;         // Stop the simulation, otherwise it runs forever!
    end
endmodule