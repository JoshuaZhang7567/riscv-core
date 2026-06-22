// ============================================================================
// File:    riscv_top.sv
// Author:  Joshua Zhang
// Project: riscv-core — Single-Cycle RV32I CPU
//
// Description:
//   Top-level module that wires together all datapath and control modules
//   for the single-cycle RV32I CPU.

import riscv_pkg::*;

module riscv_top #(
    parameter              IMEM_INIT_F     = "",    // Hex file to load into IMEM
    parameter int unsigned IMEM_DEPTH      = 1024,  // IMEM size in words (4 KiB default)
    parameter int unsigned DMEM_ADDR_WIDTH = 12     // DMEM address bits (4 KiB default)
) (
    input  logic clk,
    input  logic reset
);

    // ================================================================
    // Internal Wires
    // ================================================================

    // -- PC --
    logic [XLEN-1:0] pc_out;           // Current PC value
    logic [XLEN-1:0] pc_next;          // Next PC (output of PC source mux)
    logic [XLEN-1:0] pc_plus4;         // PC + 4
    logic [XLEN-1:0] pc_plus_imm;      // PC + ImmExt (branch/JAL target)
    logic [XLEN-1:0] jalr_target;      // ALU result with bit 0 cleared (JALR)

    // -- Instruction --
    logic [XLEN-1:0] instr;            // 32-bit instruction from IMEM

    // -- Control signals --
    logic             reg_write;
    alu_control_t     alu_ctrl;
    logic             alu_src_1;        // 0=rs1, 1=PC
    logic             alu_src_2;        // 0=rs2, 1=ImmExt
    logic             mem_write_en;
    logic             mem_read_en;
    result_src_t      result_src;       // 00=ALU, 01=MEM, 10=PC+4
    logic [1:0]       pc_src;           // 00=PC+4, 01=PC+ImmExt, 10=JALR
    imm_src_t         imm_src;

    // -- Register File --
    logic [XLEN-1:0] read_data1;       // rs1 value
    logic [XLEN-1:0] read_data2;       // rs2 value
    logic [XLEN-1:0] write_back_data;  // Data written to rd

    // -- Immediate --
    logic [XLEN-1:0] immext;           // Sign-extended immediate

    // -- ALU --
    logic [XLEN-1:0] alu_a;            // ALU input A (after mux)
    logic [XLEN-1:0] alu_b;            // ALU input B (after mux)
    logic [XLEN-1:0] alu_result;       // ALU output
    logic             alu_zero;         // ALU zero flag
    logic             alu_neg;          // ALU negative flag
    logic             alu_ovf;          // ALU overflow flag

    // -- Data Memory --
    logic [XLEN-1:0] mem_read_data;    // Data read from DMEM

    // -- JALR: clear bit 0 of ALU result per RISC-V spec --
    assign jalr_target = {alu_result[XLEN-1:1], 1'b0};

    // ================================================================
    // PC Register
    // ================================================================
    pc pc_reg (
        .clk     (clk),
        .reset   (reset),
        .pc_next (pc_next),
        .pc_out  (pc_out)
    );

    // ================================================================
    // PC + 4 Adder
    // ================================================================
    adder #(.WIDTH(XLEN)) pc_add4 (
        .a (pc_out),
        .b (32'd4),
        .y (pc_plus4)
    );

    // ================================================================
    // PC + ImmExt Adder (branch / JAL target)
    // ================================================================
    adder #(.WIDTH(XLEN)) pc_add_imm (
        .a (pc_out),
        .b (immext),
        .y (pc_plus_imm)
    );

    // ================================================================
    // PC Source Mux (3-input)
    //   00 = PC + 4          (sequential)
    //   01 = PC + ImmExt     (branch taken / JAL)
    //   10 = ALU result & ~1 (JALR)
    // ================================================================
    mux3 #(.WIDTH(XLEN)) pc_mux (
        .d0 (pc_plus4),
        .d1 (pc_plus_imm),
        .d2 (jalr_target),
        .s  (pc_src),
        .y  (pc_next)
    );

    // ================================================================
    // Instruction Memory (ROM)
    // ================================================================
    imem #(
        .DEPTH      (IMEM_DEPTH),
        .MEM_INIT_F (IMEM_INIT_F)
    ) instr_mem (
        .pc_addr (pc_out),
        .instr   (instr)
    );

    // ================================================================
    // Control Unit
    //   Instruction fields → control signals
    //   ALU flags feed back for branch decisions
    // ================================================================
    control ctrl (
        // Instruction fields
        .opcode      (opcode_t'(instr[6:0])),
        .funct3      (instr[14:12]),
        .funct7      (instr[31:25]),
        // ALU flags
        .zero        (alu_zero),
        .neg         (alu_neg),
        .ovf         (alu_ovf),
        // Control outputs
        .reg_write   (reg_write),
        .alu_control (alu_ctrl),
        .alu_src_1   (alu_src_1),
        .alu_src_2   (alu_src_2),
        .mem_write   (mem_write_en),
        .mem_read    (mem_read_en),
        .result_src  (result_src),
        .pc_src      (pc_src),
        .imm_src     (imm_src)
    );

    // ================================================================
    // Register File
    //   2 async read ports (rs1, rs2), 1 sync write port (rd)
    // ================================================================
    regfile rf (
        .clk        (clk),
        .reg_write  (reg_write),
        .rd         (instr[11:7]),
        .write_data (write_back_data),
        .rs1        (instr[19:15]),
        .read_data1 (read_data1),
        .rs2        (instr[24:20]),
        .read_data2 (read_data2)
    );

    // ================================================================
    // Immediate Generator
    // ================================================================
    immgen imm_gen (
        .instr  (instr[31:7]),
        .immsrc (imm_src),
        .immext (immext)
    );

    // ================================================================
    // ALU A-Input Mux
    //   0 = rs1 (read_data1)    — most instructions
    //   1 = PC                  — AUIPC
    // ================================================================
    mux2 #(.WIDTH(XLEN)) alu_a_mux (
        .d0 (read_data1),
        .d1 (pc_out),
        .s  (alu_src_1),
        .y  (alu_a)
    );

    // ================================================================
    // ALU B-Input Mux
    //   0 = rs2 (read_data2)    — R-type, branches
    //   1 = ImmExt              — I-type, loads, stores, LUI, AUIPC
    // ================================================================
    mux2 #(.WIDTH(XLEN)) alu_b_mux (
        .d0 (read_data2),
        .d1 (immext),
        .s  (alu_src_2),
        .y  (alu_b)
    );

    // ================================================================
    // ALU
    // ================================================================
    alu main_alu (
        .a      (alu_a),
        .b      (alu_b),
        .alu_control (alu_ctrl),
        .result (alu_result),
        .zero   (alu_zero),
        .neg    (alu_neg),
        .ovf    (alu_ovf)
    );

    // ================================================================
    // Data Memory (RAM)
    //   Address computed by ALU (base + offset)
    //   funct3 wired directly from instruction for byte/half/word select
    // ================================================================
    dmem #(.ADDR_WIDTH(DMEM_ADDR_WIDTH)) data_mem (
        .clk        (clk),
        .mem_write  (mem_write_en),
        .mem_read   (mem_read_en),
        .funct3     (instr[14:12]),
        .addr       (alu_result),
        .write_data (read_data2),
        .read_data  (mem_read_data)
    );

    // ================================================================
    // Result Mux (write-back to register file)
    //   00 = ALU result       — R-type, I-type, LUI, AUIPC
    //   01 = Memory read data — loads
    //   10 = PC + 4           — JAL, JALR (return address)
    // ================================================================
    mux3 #(.WIDTH(XLEN)) result_mux (
        .d0 (alu_result),
        .d1 (mem_read_data),
        .d2 (pc_plus4),
        .s  (result_src),
        .y  (write_back_data)
    );

endmodule
