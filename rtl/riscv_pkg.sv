// ============================================================================
// File:    riscv_pkg.sv
// Author:  Joshua Zhang
// Project: riscv-core — Single-Cycle RV32I CPU
//
// Description:
//   Shared package for the RV32I CPU. Defines opcodes, funct fields, ALU
//   control codes, and all control-signal types used across the datapath.
//
// Datapath Modules (matching block diagram):
//   PC  →  IMEM  →  CU  →  RegFile  →  ALU  →  DMEM
//                    ↓       Extend          ↓
//               Control signals          Result MUX
//
// Reference:
//   Harris & Harris, Digital Design & Computer Architecture: RISC-V Edition
//   RISC-V Unprivileged ISA Specification v20191213
// ============================================================================

package riscv_pkg;

  // ==========================================================================
  // Word Widths
  // ==========================================================================
  localparam int XLEN       = 32;          // Data width
  localparam int REG_ADDR_W = 5;           // Register address width (32 regs)
  localparam int NUM_REGS   = 32;          // Number of registers

  // ==========================================================================
  // Opcodes  —  op field, instr[6:0]
  // ==========================================================================
  typedef enum logic [6:0] {
    OP_LUI      = 7'b0110111,   // Load Upper Immediate
    OP_AUIPC    = 7'b0010111,   // Add Upper Immediate to PC
    OP_JAL      = 7'b1101111,   // Jump and Link
    OP_JALR     = 7'b1100111,   // Jump and Link Register
    OP_BRANCH   = 7'b1100011,   // Conditional Branch (BEQ, BNE, BLT, ...)
    OP_LOAD     = 7'b0000011,   // Load (LB, LH, LW, LBU, LHU)
    OP_STORE    = 7'b0100011,   // Store (SB, SH, SW)
    OP_IMM      = 7'b0010011,   // Register-Immediate (ADDI, SLTI, ...)
    OP_REG      = 7'b0110011,   // Register-Register  (ADD, SUB, ...)
    OP_FENCE    = 7'b0001111,   // Memory Fence
    OP_SYSTEM   = 7'b1110011    // System (ECALL, EBREAK)
  } opcode_t;

  // ==========================================================================
  // funct3 Encodings — Grouped by Opcode
  // ==========================================================================

  // --- ALU: R-type (OP_REG) & I-type (OP_IMM) ---
  typedef enum logic [2:0] {
    F3_ADD_SUB  = 3'b000,       // ADD / SUB (distinguished by funct7)
    F3_SLL      = 3'b001,       // Shift Left Logical
    F3_SLT      = 3'b010,       // Set Less Than (signed)
    F3_SLTU     = 3'b011,       // Set Less Than (unsigned)
    F3_XOR      = 3'b100,       // Bitwise XOR
    F3_SRL_SRA  = 3'b101,       // Shift Right Logical / Arithmetic (funct7)
    F3_OR       = 3'b110,       // Bitwise OR
    F3_AND      = 3'b111        // Bitwise AND
  } funct3_alu_t;

  // --- Branch (OP_BRANCH) ---
  typedef enum logic [2:0] {
    F3_BEQ      = 3'b000,       // Branch if Equal
    F3_BNE      = 3'b001,       // Branch if Not Equal
    F3_BLT      = 3'b100,       // Branch if Less Than (signed)
    F3_BGE      = 3'b101,       // Branch if Greater or Equal (signed)
    F3_BLTU     = 3'b110,       // Branch if Less Than (unsigned)
    F3_BGEU     = 3'b111        // Branch if Greater or Equal (unsigned)
  } funct3_branch_t;

  // --- Load (OP_LOAD) ---
  typedef enum logic [2:0] {
    F3_LB       = 3'b000,       // Load Byte (sign-extended)
    F3_LH       = 3'b001,       // Load Halfword (sign-extended)
    F3_LW       = 3'b010,       // Load Word
    F3_LBU      = 3'b100,       // Load Byte (zero-extended)
    F3_LHU      = 3'b101        // Load Halfword (zero-extended)
  } funct3_load_t;

  // --- Store (OP_STORE) ---
  typedef enum logic [2:0] {
    F3_SB       = 3'b000,       // Store Byte
    F3_SH       = 3'b001,       // Store Halfword
    F3_SW       = 3'b010        // Store Word
  } funct3_store_t;

  // ==========================================================================
  // funct7 Encodings
  // ==========================================================================
  typedef enum logic [6:0] {
    F7_NORMAL   = 7'b0000000,   // ADD, SRL, etc.
    F7_ALT      = 7'b0100000    // SUB, SRA
  } funct7_t;

  // ==========================================================================
  // Control Signals — CU (Control Unit) outputs
  //   These types define the mux-select and enable signals that the CU
  //   drives across the datapath.
  // ==========================================================================

  // --- ResultSrc: selects write-back data to RegFile (wd3) ---
  //   Controls the result MUX at the far right of the datapath
  typedef enum logic [1:0] {
    RESULT_ALU      = 2'b00,    // ALUResult
    RESULT_MEM      = 2'b01,    // ReadData from DMEM
    RESULT_PC4      = 2'b10     // PCPlus4  (for JAL/JALR return address)
  } result_src_t;

  // --- ImmSrc: selects immediate format in the Extend unit ---
  typedef enum logic [2:0] {
    IMM_I       = 3'b000,       // I-type: instr[31:20]
    IMM_S       = 3'b001,       // S-type: {instr[31:25], instr[11:7]}
    IMM_B       = 3'b010,       // B-type: branch offset
    IMM_U       = 3'b011,       // U-type: instr[31:12] << 12
    IMM_J       = 3'b100        // J-type: JAL offset
  } imm_src_t;

  // --- ALUOp: intermediate signal from Main Decoder → ALU Decoder ---
  //   Tells the ALU Decoder how to interpret funct3/funct7
  typedef enum logic [1:0] {
    ALUOP_ADD    = 2'b00,       // Force ADD (Load / Store / AUIPC)
    ALUOP_SUB    = 2'b01,       // Force SUB (Branch comparison)
    ALUOP_FUNC   = 2'b10       // Decode from funct3 + funct7 (R-type / I-type)
  } alu_op_t;

  // --- ALUControl: operation select driven into the ALU ---
  //   Directly controls the ALU datapath mux
  typedef enum logic [3:0] {
    ALU_ADD     = 4'b0000,      // A + B
    ALU_SUB     = 4'b0001,      // A - B
    ALU_AND     = 4'b0010,      // A & B
    ALU_OR      = 4'b0011,      // A | B
    ALU_XOR     = 4'b0100,      // A ^ B
    ALU_SLT     = 4'b0101,      // Signed   (A < B) ? 1 : 0
    ALU_SLTU    = 4'b0110,      // Unsigned (A < B) ? 1 : 0
    ALU_SLL     = 4'b0111,      // A << B[4:0]
    ALU_SRL     = 4'b1000,      // A >> B[4:0]  (logical)
    ALU_SRA     = 4'b1001,      // A >>> B[4:0] (arithmetic)
    ALU_PASS_B  = 4'b1010       // Pass B through (LUI)
  } alu_control_t;

  // ==========================================================================
  // Instruction Field Extraction Functions
  //   Field names match the datapath diagram:
  //     op = instr[6:0],  rd = instr[11:7],   funct3 = instr[14:12]
  //     rs1 = instr[19:15], rs2 = instr[24:20], funct7 = instr[31:25]
  // ==========================================================================
  function automatic logic [6:0] get_op(input logic [31:0] instr);
    return instr[6:0];
  endfunction

  function automatic logic [4:0] get_rd(input logic [31:0] instr);
    return instr[11:7];
  endfunction

  function automatic logic [2:0] get_funct3(input logic [31:0] instr);
    return instr[14:12];
  endfunction

  function automatic logic [4:0] get_rs1(input logic [31:0] instr);
    return instr[19:15];
  endfunction

  function automatic logic [4:0] get_rs2(input logic [31:0] instr);
    return instr[24:20];
  endfunction

  function automatic logic [6:0] get_funct7(input logic [31:0] instr);
    return instr[31:25];
  endfunction

  // ==========================================================================
  // Immediate Extraction Functions
  //   Return the sign-extended 32-bit immediate (ImmExt) for each format
  // ==========================================================================
  function automatic logic [31:0] get_imm_i(input logic [31:0] instr);
    return {{20{instr[31]}}, instr[31:20]};
  endfunction

  function automatic logic [31:0] get_imm_s(input logic [31:0] instr);
    return {{20{instr[31]}}, instr[31:25], instr[11:7]};
  endfunction

  function automatic logic [31:0] get_imm_b(input logic [31:0] instr);
    return {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
  endfunction

  function automatic logic [31:0] get_imm_u(input logic [31:0] instr);
    return {instr[31:12], 12'b0};
  endfunction

  function automatic logic [31:0] get_imm_j(input logic [31:0] instr);
    return {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
  endfunction

endpackage
