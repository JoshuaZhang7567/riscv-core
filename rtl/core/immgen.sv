import riscv_pkg::*;

module immgen(input  logic [31:7]  instr,
              input  imm_src_t     immsrc,  
              output logic [XLEN-1:0] immext);

  always_comb
    case(immsrc)
                // I-type (loads, immediate arithmetic)
      IMM_I:   immext = {{20{instr[31]}}, instr[31:20]};
      
                // S-type (stores)
      IMM_S:   immext = {{20{instr[31]}}, instr[31:25],
                          instr[11:7]};
                          
                // B-type (branches)
      IMM_B:   immext = {{20{instr[31]}}, instr[7],
                          instr[30:25], instr[11:8], 1'b0};
                          
                // J-type (jal)
      IMM_J:   immext = {{12{instr[31]}}, instr[19:12],
                          instr[20], instr[30:21], 1'b0};
                          
                // U-type (lui, auipc)
      IMM_U:   immext = {instr[31:12], 12'b0};
      
      default: immext = {XLEN{1'bx}}; // undefined
    endcase

endmodule