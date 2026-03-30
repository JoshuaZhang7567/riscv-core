// -------------------------------------------------------------------------
// File: rtl/riscv_pkg.sv
// Description: Global package containing all RV32I opcodes, function codes, 
//              and internal control signals.
// -------------------------------------------------------------------------

package riscv_pkg;

    // Standard 32-bit data word
    typedef logic [31:0] word_t;

    // ========================================================================
    // 1. OPCODES (Instruction bits [6:0])
    // ========================================================================
    typedef enum logic [6:0] {
        OP_LOAD   = 7'b0000011, // lw, lh, lb, lhu, lbu
        OP_IMM    = 7'b0010011, // addi, slti, andi, etc. (I-type)
        OP_AUIPC  = 7'b0010111, // auipc
        OP_STORE  = 7'b0100011, // sw, sh, sb
        OP_REG    = 7'b0110011, // add, sub, and, etc. (R-type)
        OP_LUI    = 7'b0110111, // lui
        OP_BRANCH = 7'b1100011, // beq, bne, blt, bge, bltu, bgeu
        OP_JALR   = 7'b1100111, // jalr
        OP_JAL    = 7'b1101111  // jal
    } opcode_t;

    // ========================================================================
    // 2. FUNCT3 CODES (Instruction bits [14:12])
    // ========================================================================
    // Named primarily after their R-type/I-type math operations, but these 
    // are reused for Branches and Loads/Stores.
    typedef enum logic [2:0] {
        F3_ADD_SUB = 3'b000, // add, sub, addi, beq, lb, sb
        F3_SLL     = 3'b001, // sll, slli, bne, lh, sh
        F3_SLT     = 3'b010, // slt, slti, lw, sw
        F3_SLTU    = 3'b011, // sltu, sltiu
        F3_XOR     = 3'b100, // xor, xori, blt, lbu
        F3_SRL_SRA = 3'b101, // srl, sra, srli, srai, bge, lhu
        F3_OR      = 3'b110, // or, ori, bltu
        F3_AND     = 3'b111  // and, andi, bgeu
    } funct3_t;

    // ========================================================================
    // 3. FUNCT7 CODES (Instruction bits [31:25])
    // ========================================================================
    // Used to differentiate variants of instructions that share an opcode and funct3
    // (e.g., ADD vs SUB, or SRL vs SRA).
    typedef enum logic [6:0] {
        F7_BASE = 7'b0000000, // Standard (add, sll, xor, srl, or, and)
        F7_ALT  = 7'b0100000  // Alternate/Arithmetic (sub, sra)
    } funct7_t;

    // ========================================================================
    // 4. ALU CONTROL SIGNALS (Our internal wire codes)
    // ========================================================================
    typedef enum logic [3:0] {
        ALU_ADD  = 4'b0000,
        ALU_SUB  = 4'b1000,
        ALU_SLL  = 4'b0001,
        ALU_SLT  = 4'b0010,
        ALU_SLTU = 4'b0011,
        ALU_XOR  = 4'b0100,
        ALU_SRL  = 4'b0101,
        ALU_SRA  = 4'b1101,
        ALU_OR   = 4'b0110,
        ALU_AND  = 4'b0111
    } alu_op_t;

    // ========================================================================
    // 5. DECODED INSTRUCTION STRUCT
    // ========================================================================
    // Packed strictly from MSB to LSB so it maps perfectly onto a 32-bit wire
    typedef struct packed {
        logic [6:0] funct7; // Bits [31:25]
        logic [4:0] rs2;    // Bits [24:20]
        logic [4:0] rs1;    // Bits [19:15]
        logic [2:0] funct3; // Bits [14:12]
        logic [4:0] rd;     // Bits [11:7]
        opcode_t    opcode; // Bits [6:0]
    } r_instr_t;

endpackage