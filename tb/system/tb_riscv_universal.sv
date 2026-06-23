// ============================================================================
// Universal Testbench for Single-Cycle RV32I CPU
//
// This testbench can run ANY test program without modification.
// It reads two files from the command line:
//   +HEX_FILE=<path>       — the program to load into IMEM
//   +EXPECTED=<path>        — the expected results to check
//
// Usage:
//   vvp tb_riscv_universal.out +HEX_FILE=sw/asm/test_basic.hex \
//                              +EXPECTED=sw/asm/test_basic.expected
// ============================================================================

`timescale 1ns / 1ps

import riscv_pkg::*;

module tb_riscv_universal;

    // ================================================================
    // SECTION 1: Clock Generation
    // ================================================================
    logic clk, reset;

    initial clk = 0;
    always #5 clk = ~clk;

    // ================================================================
    // SECTION 2: CPU Instantiation (Device Under Test)
    // ================================================================
    riscv_top #(
        .IMEM_INIT_F (""),           // Empty! Loaded dynamically below.
        .IMEM_DEPTH  (1024),
        .DMEM_ADDR_WIDTH (12)
    ) dut (
        .clk   (clk),
        .reset (reset)
    );

    // ================================================================
    // SECTION 3: Test Scoreboard

    // ================================================================
    integer pass_count = 0;
    integer fail_count = 0;

    // --- Task: Check that a register EQUALS an expected value ---
    //   Used for instructions we expect to have executed successfully.
    //   Example: after "addi x1, x0, 5", we expect x1 == 5.
    task automatic check_reg_eq(input int addr, input [31:0] expected);
        if (dut.rf.rf[addr] === expected) begin
            $display("  [PASS] x%-2d = 0x%08h (%0d)", addr, expected, expected);
            pass_count++;
        end else begin
            $display("  [FAIL] x%-2d = 0x%08h  (expected 0x%08h)",
                     addr, dut.rf.rf[addr], expected);
            fail_count++;
        end
    endtask

    // --- Task: Check that a register does NOT equal a bad value ---
    //   Used for instructions that should have been SKIPPED by a
    //   branch or jump. If the register still holds the bad value,
    //   it means the branch/jump failed to skip the instruction.
    task automatic check_reg_neq(input int addr, input [31:0] bad_val);
        if (dut.rf.rf[addr] !== bad_val) begin
            $display("  [PASS] x%-2d != 0x%08h (skipped)", addr, bad_val);
            pass_count++;
        end else begin
            $display("  [FAIL] x%-2d = 0x%08h  (should have been skipped!)",
                     addr, dut.rf.rf[addr]);
            fail_count++;
        end
    endtask

    // --- Task: Check that a memory word EQUALS an expected value ---
    //   Used for store instructions (SW, SH, SB). We peek directly
    //   into the data memory's internal RAM array.
    task automatic check_mem_eq(input int addr, input [31:0] expected);
        if (dut.data_mem.ram[addr] === expected) begin
            $display("  [PASS] mem[%0d] = 0x%08h (%0d)", addr, expected, expected);
            pass_count++;
        end else begin
            $display("  [FAIL] mem[%0d] = 0x%08h  (expected 0x%08h)",
                     addr, dut.data_mem.ram[addr], expected);
            fail_count++;
        end
    endtask

    // ================================================================
    // SECTION 4: Main Test Sequence
    //
    //   This is where everything actually happens, step by step:
    //   1. Read the .hex and .expected filenames from the command line
    //   2. Load the program into the CPU's instruction memory
    //   3. Reset the CPU
    //   4. Let the CPU run for a configurable number of cycles
    //   5. Read the .expected file and run every check
    //   6. Print a summary (pass/fail counts)
    // ================================================================

    // Variables to hold the filenames from the command line.
    // In Verilog, strings are stored in large reg arrays (8 bits per char).
    // 128 characters max should be enough for any reasonable file path.
    reg [128*8-1:0] hex_file;
    reg [128*8-1:0] expected_file;

    // Variables used for parsing the .expected file.
    integer fd;               // File descriptor (handle) returned by $fopen
    integer r;                // Return value from $fscanf (number of items read)
    integer num_cycles_cfg;   // How many clock cycles to run the program
    integer check_type;       // 0 = reg equals, 1 = reg not-equals, 2 = mem equals
    integer check_addr;       // Register number (0-31) or memory word address
    reg [31:0] check_value;   // The expected (or forbidden) 32-bit value

    initial begin
        // --- Waveform recording (for GTKWave) ---
        $dumpfile("sim/waveforms/riscv_universal.vcd");
        $dumpvars(0, tb_riscv_universal);

        // ============================================================
        // STEP 1: Read command-line arguments
        //
        //   $value$plusargs searches the command line for a +NAME=VALUE
        //   argument. When you run:
        //     vvp sim.out +HEX_FILE=sw/asm/test_basic.hex
        //   it finds "+HEX_FILE=" and stores "sw/asm/test_basic.hex"
        //   into the hex_file variable.
        //
        //   If the argument is missing, we print an error and quit.
        // ============================================================
        if (!$value$plusargs("HEX_FILE=%s", hex_file)) begin
            $display("ERROR: No program specified.");
            $display("  Usage: vvp <out_file> +HEX_FILE=<path.hex> +EXPECTED=<path.expected>");
            $finish;
        end
        if (!$value$plusargs("EXPECTED=%s", expected_file)) begin
            $display("ERROR: No expected-results file specified.");
            $display("  Usage: vvp <out_file> +HEX_FILE=<path.hex> +EXPECTED=<path.expected>");
            $finish;
        end

        // ============================================================
        // STEP 2: Load the program into instruction memory
        //
        //   We pull reset HIGH first so the CPU is frozen. While it's
        //   frozen, we use $readmemh to inject the .hex file directly
        //   into the IMEM module's internal ROM array. This is a
        //   hierarchical reference: dut → instr_mem → rom.
        //
        //   We didn't need to hardcode the filename in the parameter
        //   because we're loading it here at runtime instead.
        // ============================================================
        reset = 1;
        $readmemh(hex_file, dut.instr_mem.rom);

        // ============================================================
        // STEP 3: Open the expected-results file and read cycle count
        //
        //   The .expected file format is simple:
        //     Line 1:  number of clock cycles to run
        //     Line 2+: <type> <address> <hex_value>
        //       type 0 = register must equal value
        //       type 1 = register must NOT equal value
        //       type 2 = memory word must equal value
        //
        //   $fopen opens the file and returns a "file descriptor" (fd).
        //   $fscanf reads formatted data from the file, just like
        //   scanf() in C. The "%d" reads one decimal integer.
        // ============================================================
        fd = $fopen(expected_file, "r");
        if (fd == 0) begin
            $display("ERROR: Cannot open file: %0s", expected_file);
            $finish;
        end
        r = $fscanf(fd, "%d", num_cycles_cfg);
        if (r != 1) begin
            $display("ERROR: Could not read cycle count from %0s", expected_file);
            $finish;
        end

        // ============================================================
        // STEP 4: Reset sequence
        //
        //   Hold reset high for 2 rising clock edges, then release on
        //   the next falling edge. This ensures the PC register is
        //   cleanly initialized to 0 before the CPU starts fetching.
        // ============================================================
        repeat(2) @(posedge clk);
        @(negedge clk);
        reset = 0;

        // ============================================================
        // STEP 5: Let the CPU run
        //
        //   The testbench script pauses here for num_cycles_cfg clock
        //   cycles. During this pause, the background clock keeps
        //   ticking and the CPU executes instructions from IMEM.
        // ============================================================
        $display("");
        $display("Running %0s for %0d cycles...", hex_file, num_cycles_cfg);
        repeat(num_cycles_cfg) @(posedge clk);

        // ============================================================
        // STEP 6: Read checks from the .expected file and verify
        //
        //   $fscanf reads three values per line: type, address, value.
        //   "%d %d %h" means: decimal, decimal, hexadecimal.
        //   It returns 3 if all three were read successfully.
        //
        //   We loop until End-Of-File ($feof), running the appropriate
        //   check task for each line based on the type code.
        // ============================================================
        $display("");
        $display("================================================================");
        $display("  Test Results: %0s", hex_file);
        $display("================================================================");

        while (!$feof(fd)) begin
            r = $fscanf(fd, "%d %d %h", check_type, check_addr, check_value);
            if (r == 3) begin
                case (check_type)
                    0: check_reg_eq (check_addr, check_value);
                    1: check_reg_neq(check_addr, check_value);
                    2: check_mem_eq (check_addr, check_value);
                    default: $display("  [WARN] Unknown check type: %0d", check_type);
                endcase
            end
        end

        $fclose(fd);

        // ============================================================
        // STEP 7: Print summary and exit
        // ============================================================
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
