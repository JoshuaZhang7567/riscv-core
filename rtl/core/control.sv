// ============================================================================
// Control Unit for Single-Cycle RV32I CPU
//
// Decodes the instruction fields (opcode, funct3, funct7) and ALU flags
// to produce all datapath control signals.
//
// Covers all 40 unprivileged RV32I instructions:
//   R-type:  ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
//   I-type:  ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
//   Load:    LB, LH, LW, LBU, LHU
//   Store:   SB, SH, SW
//   Branch:  BEQ, BNE, BLT, BGE, BLTU, BGEU
//   Jump:    JAL, JALR
//   Upper:   LUI, AUIPC
//   System:  FENCE, ECALL, EBREAK  (treated as NOPs)
// ============================================================================

import riscv_pkg::*;

module control (
    // ---- Instruction fields (from IMEM) ----
    input  opcode_t              opcode,       // instr[6:0]
    input  logic [2:0]           funct3,       // instr[14:12]
    input  logic [6:0]           funct7,       // instr[31:25]

    // ---- ALU flags (from ALU, needed for branch decisions) ----
    input  logic                 zero,         // ALU result == 0
    input  logic                 neg,          // ALU result[31]
    input  logic                 ovf,          // ALU signed overflow

    // ---- Control outputs ----
    output logic                 reg_write,    // RegFile write enable
    output alu_control_t         alu_control,  // ALU operation select
    output logic                 alu_src_1,    // ALU A-input mux: 0=rs1, 1=PC
    output logic                 alu_src_2,    // ALU B-input mux: 0=rs2, 1=ImmExt
    output logic                 mem_write,    // DMEM write enable
    output logic                 mem_read,     // DMEM read enable
    output result_src_t          result_src,   // Write-back mux: ALU=00, MEM=01, PC+4=10
    output logic [1:0]           pc_src,       // PC mux: PC+4=00, PC+ImmExt=01, ALUResult=10
    output imm_src_t             imm_src       // Immediate format select
);

    // Internal signal for branch decision
    logic branch_taken;

    always_comb begin
        // ================================================================
        // Safe defaults — no writes, no branches, ALU adds rs1+rs2
        // (prevents latches for signals not explicitly set in each case)
        // ================================================================
        reg_write    = 1'b0;
        alu_control  = ALU_ADD;
        alu_src_1    = 1'b0;        // rs1
        alu_src_2    = 1'b0;        // rs2
        mem_write    = 1'b0;
        mem_read     = 1'b0;
        result_src   = RESULT_ALU;
        pc_src       = 2'b00;       // PC + 4
        imm_src      = IMM_I;
        branch_taken = 1'b0;

        case (opcode)

            // ============================================================
            // R-type: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
            // ============================================================
            OP_REG: begin
                reg_write  = 1'b1;
                alu_src_2  = 1'b0;          // rs2
                result_src = RESULT_ALU;
                case (funct3)
                    F3_ADD_SUB: begin
                        if (funct7 == F7_ALT) alu_control = ALU_SUB;
                        else                  alu_control = ALU_ADD;
                    end
                    F3_SLL:     alu_control = ALU_SLL;
                    F3_SLT:     alu_control = ALU_SLT;
                    F3_SLTU:    alu_control = ALU_SLTU;
                    F3_XOR:     alu_control = ALU_XOR;
                    F3_SRL_SRA: begin
                        if (funct7 == F7_ALT) alu_control = ALU_SRA;
                        else                  alu_control = ALU_SRL;
                    end
                    F3_OR:      alu_control = ALU_OR;
                    F3_AND:     alu_control = ALU_AND;
                    default:    alu_control = ALU_ADD;
                endcase
            end

            // ============================================================
            // I-type ALU: ADDI, SLTI, SLTIU, XORI, ORI, ANDI,
            //             SLLI, SRLI, SRAI
            // ============================================================
            OP_IMM: begin
                reg_write  = 1'b1;
                alu_src_2  = 1'b1;          // immediate
                imm_src    = IMM_I;
                result_src = RESULT_ALU;
                case (funct3)
                    F3_ADD_SUB: alu_control = ALU_ADD;      // ADDI
                    F3_SLL:     alu_control = ALU_SLL;      // SLLI
                    F3_SLT:     alu_control = ALU_SLT;      // SLTI
                    F3_SLTU:    alu_control = ALU_SLTU;     // SLTIU
                    F3_XOR:     alu_control = ALU_XOR;      // XORI
                    F3_SRL_SRA: begin
                        if (funct7 == F7_ALT) alu_control = ALU_SRA;
                        else                  alu_control = ALU_SRL;
                    end
                    F3_OR:      alu_control = ALU_OR;       // ORI
                    F3_AND:     alu_control = ALU_AND;      // ANDI
                    default:    alu_control = ALU_ADD;
                endcase
            end

            // ============================================================
            // Load: LB, LH, LW, LBU, LHU
            //   ALU computes address: rs1 + ImmExt
            //   funct3 passed directly to DMEM (wired in top-level)
            // ============================================================
            OP_LOAD: begin
                reg_write   = 1'b1;
                alu_src_2   = 1'b1;         // immediate (offset)
                alu_control = ALU_ADD;      // base + offset
                mem_read    = 1'b1;
                result_src  = RESULT_MEM;   // write memory data to rd
                imm_src     = IMM_I;
            end

            // ============================================================
            // Store: SB, SH, SW
            //   ALU computes address: rs1 + ImmExt
            //   funct3 passed directly to DMEM (wired in top-level)
            // ============================================================
            OP_STORE: begin
                alu_src_2   = 1'b1;         // immediate (offset)
                alu_control = ALU_ADD;      // base + offset
                mem_write   = 1'b1;
                imm_src     = IMM_S;
            end

            // ============================================================
            // Branch: BEQ, BNE, BLT, BGE, BLTU, BGEU
            //   ALU operation varies by branch type:
            //     BEQ/BNE   → SUB,  check zero flag
            //     BLT/BGE   → SLT,  check zero flag (result=1 means a<b)
            //     BLTU/BGEU → SLTU, check zero flag (result=1 means a<b)
            // ============================================================
            OP_BRANCH: begin
                alu_src_2 = 1'b0;           // rs2 (compare two registers)
                imm_src   = IMM_B;

                // Select ALU operation per branch type
                case (funct3)
                    F3_BEQ, F3_BNE:   alu_control = ALU_SUB;   // subtract to test equality
                    F3_BLT, F3_BGE:   alu_control = ALU_SLT;   // signed less-than
                    F3_BLTU, F3_BGEU: alu_control = ALU_SLTU;  // unsigned less-than
                    default:          alu_control = ALU_SUB;
                endcase

                // Evaluate branch condition from ALU flags
                case (funct3)
                    F3_BEQ:  branch_taken =  zero;  // SUB==0 → equal
                    F3_BNE:  branch_taken = ~zero;  // SUB!=0 → not equal
                    F3_BLT:  branch_taken = ~zero;  // SLT result=1 → rs1 < rs2 (signed)
                    F3_BGE:  branch_taken =  zero;  // SLT result=0 → rs1 >= rs2 (signed)
                    F3_BLTU: branch_taken = ~zero;  // SLTU result=1 → rs1 < rs2 (unsigned)
                    F3_BGEU: branch_taken =  zero;  // SLTU result=0 → rs1 >= rs2 (unsigned)
                    default: branch_taken = 1'b0;
                endcase

                pc_src = branch_taken ? 2'b01 : 2'b00;  // 01=PC+ImmExt, 00=PC+4
            end

            // ============================================================
            // JAL: Jump and Link
            //   PC ← PC + ImmExt (J-type offset)
            //   rd ← PC + 4      (return address)
            // ============================================================
            OP_JAL: begin
                reg_write  = 1'b1;
                result_src = RESULT_PC4;    // save PC+4 to rd
                pc_src     = 2'b01;         // PC + ImmExt
                imm_src    = IMM_J;
            end

            // ============================================================
            // JALR: Jump and Link Register
            //   PC ← (rs1 + ImmExt) & ~1   (bit 0 cleared in top-level)
            //   rd ← PC + 4                (return address)
            // ============================================================
            OP_JALR: begin
                reg_write   = 1'b1;
                alu_src_2   = 1'b1;         // immediate
                alu_control = ALU_ADD;      // rs1 + ImmExt
                result_src  = RESULT_PC4;   // save PC+4 to rd
                pc_src      = 2'b10;        // ALU result → PC
                imm_src     = IMM_I;
            end

            // ============================================================
            // LUI: Load Upper Immediate
            //   rd ← ImmExt  (upper 20 bits, lower 12 zeroed by ImmGen)
            // ============================================================
            OP_LUI: begin
                reg_write   = 1'b1;
                alu_src_2   = 1'b1;         // immediate
                alu_control = ALU_PASS_B;   // pass ImmExt straight through
                result_src  = RESULT_ALU;
                imm_src     = IMM_U;
            end

            // ============================================================
            // AUIPC: Add Upper Immediate to PC
            //   rd ← PC + ImmExt
            // ============================================================
            OP_AUIPC: begin
                reg_write   = 1'b1;
                alu_src_1   = 1'b1;         // PC (not rs1)
                alu_src_2   = 1'b1;         // immediate
                alu_control = ALU_ADD;      // PC + ImmExt
                result_src  = RESULT_ALU;
                imm_src     = IMM_U;
            end

            // ============================================================
            // FENCE — NOP in single-cycle (no reordering possible)
            // ECALL / EBREAK — NOP (would need trap logic)
            // ============================================================
            OP_FENCE,
            OP_SYSTEM: begin
                // All defaults apply — no state changes
            end

            default: begin
                // Unknown opcode — defaults act as NOP
            end

        endcase
    end

endmodule
