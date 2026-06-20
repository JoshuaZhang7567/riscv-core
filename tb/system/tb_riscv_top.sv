// ============================================================================
// System Testbench for Single-Cycle RV32I CPU
//
// Loads test_basic.hex into IMEM, runs the CPU, and checks register/memory
// values against expected results.
// ============================================================================

`timescale 1ns / 1ps

import riscv_pkg::*;

module tb_riscv_top;

    // ----------------------------------------------------------------
    // Clock and reset
    // ----------------------------------------------------------------
    logic clk, reset;

    initial clk = 0;
    always #5 clk = ~clk;  // 10ns period → 100 MHz

    // ----------------------------------------------------------------
    // DUT instantiation
    // ----------------------------------------------------------------
    riscv_top #(
        .IMEM_INIT_F ("sw/asm/test_basic.hex"),
        .IMEM_DEPTH  (1024),
        .DMEM_ADDR_WIDTH (12)
    ) dut (
        .clk   (clk),
        .reset (reset)
    );

    // ----------------------------------------------------------------
    // Test infrastructure
    // ----------------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;

    // Check a register value (exact match)
    task automatic check_reg(input int reg_num, input int expected, input string name);
        if (dut.rf.rf[reg_num] === expected[31:0]) begin
            $display("  [PASS] %-30s : x%-2d = 0x%08h (%0d)", name, reg_num, expected, expected);
            pass_count++;
        end else begin
            $display("  [FAIL] %-30s : x%-2d = 0x%08h  (expected 0x%08h)",
                     name, reg_num, dut.rf.rf[reg_num], expected);
            fail_count++;
        end
    endtask

    // Check a register was NOT written with a specific value (for skipped instructions)
    task automatic check_reg_not(input int reg_num, input int bad_val, input string name);
        if (dut.rf.rf[reg_num] !== bad_val[31:0]) begin
            $display("  [PASS] %-30s : x%-2d != %0d (instruction was skipped)", name, reg_num, bad_val);
            pass_count++;
        end else begin
            $display("  [FAIL] %-30s : x%-2d = %0d  (instruction was NOT skipped!)",
                     name, reg_num, bad_val);
            fail_count++;
        end
    endtask

    // Check a memory word
    task automatic check_mem(input int word_addr, input int expected, input string name);
        if (dut.data_mem.ram[word_addr] === expected[31:0]) begin
            $display("  [PASS] %-30s : mem[%0d] = %0d", name, word_addr, expected);
            pass_count++;
        end else begin
            $display("  [FAIL] %-30s : mem[%0d] = 0x%08h  (expected 0x%08h)",
                     name, word_addr, dut.data_mem.ram[word_addr], expected);
            fail_count++;
        end
    endtask

    // ----------------------------------------------------------------
    // Main test sequence
    // ----------------------------------------------------------------
    initial begin
        // Dump waveforms for GTKWave
        $dumpfile("sim/waveforms/riscv_top.vcd");
        $dumpvars(0, tb_riscv_top);

        // ---- Reset ----
        reset = 1;
        repeat(2) @(posedge clk);
        @(negedge clk);
        reset = 0;

        // ---- Run program ----
        // 13 instructions (including NOPs), plus margin for branch/jump timing
        repeat(20) @(posedge clk);

        // ---- Check results ----
        $display("");
        $display("================================================================");
        $display("  RV32I CPU Test Results — test_basic.hex");
        $display("================================================================");

        // --- R-type & I-type ALU ---
        check_reg(1,  5,  "ADDI x1, x0, 5");
        check_reg(2,  3,  "ADDI x2, x0, 3");
        check_reg(3,  8,  "ADD  x3, x1, x2");
        check_reg(4,  2,  "SUB  x4, x1, x2");

        // --- Load/Store ---
        check_mem(0,  8,  "SW   x3, 0(x0)");
        check_reg(5,  8,  "LW   x5, 0(x0)");

        // --- Branch (BEQ taken → skip x6) ---
        check_reg_not(6, 99, "BEQ skip (x6 != 99)");
        check_reg(7,  1,     "ADDI x7, x0, 1  (branch target)");

        // --- Jump (JAL → skip x9, save return addr) ---
        check_reg(8,  32'h28, "JAL  x8  (return addr = 0x28)");
        check_reg_not(9, 99,  "JAL skip (x9 != 99)");
        check_reg(10, 42,     "ADDI x10, x0, 42 (JAL target)");

        // ---- Summary ----
        $display("");
        $display("----------------------------------------------------------------");
        $display("  Passed: %0d   Failed: %0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("  >>> ALL TESTS PASSED <<<");
        else
            $display("  >>> SOME TESTS FAILED <<<");
        $display("----------------------------------------------------------------");
        $display("");

        $finish;
    end

endmodule
