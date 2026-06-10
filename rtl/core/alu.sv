//     ALU_SLT    (0101)  →  signed   (a < b) ? 1 : 0
//     ALU_SLTU   (0110)  →  unsigned (a < b) ? 1 : 0
//     ALU_SLL    (0111)  →  a << b[4:0]
//     ALU_SRL    (1000)  →  a >> b[4:0]   (logical)
//     ALU_SRA    (1001)  →  a >>> b[4:0]  (arithmetic)
//     ALU_PASS_B (1010)  →  b             (LUI: passes ImmExt straight through)
//
//   Flags:
//     zero  — result == 0  (used by branch logic: BEQ/BNE on SUB, BLT on SLT)
//     neg   — result[31]   (sign bit, useful for richer branch decoding)
//     ovf   — signed overflow (optional; useful for full flag-based branching)

import riscv_pkg::*;

module alu (
    input  logic [XLEN-1:0]       a,            // Operand A (rs1 or PC)
    input  logic [XLEN-1:0]       b,            // Operand B (rs2 or ImmExt)
    input  alu_control_t          alu_control,  // Operation select

    output logic [XLEN-1:0]       result,       // ALU result
    output logic                  zero,         // result == 0
    output logic                  neg,          // result[31] (sign bit)
    output logic                  ovf           // Signed overflow
);

  logic [XLEN-1:0] sum;
  logic            cout;

  //Addition / Subtraction shared path
  always_comb begin
    if (alu_control == ALU_SUB)
      {cout, sum} = {1'b0, a} + {1'b0, ~b} + 33'd1;
    else
      {cout, sum} = {1'b0, a} + {1'b0,  b};
  end

  always_comb begin
    unique case (alu_control)
      ALU_ADD:    result = sum;
      ALU_SUB:    result = sum;
      ALU_AND:    result = a & b;
      ALU_OR:     result = a | b;
      ALU_XOR:    result = a ^ b;
      ALU_SLT:    result = {{(XLEN-1){1'b0}}, ($signed(a) < $signed(b))};
      ALU_SLTU:   result = {{(XLEN-1){1'b0}}, (a < b)};
      ALU_SLL:    result = a << b[4:0];
      ALU_SRL:    result = a >> b[4:0];
      ALU_SRA:    result = $signed(a) >>> b[4:0];
      ALU_PASS_B: result = b;
      default:    result = '0;
    endcase
  end

  assign zero = (result == '0);
  assign neg  = result[XLEN-1];

  // Signed overflow: occurs on ADD/SUB when operand signs predict one result
  // sign but the output sign differs.
  //   ADD ovf: a[31]==b[31] but result[31] differs
  //   SUB ovf: a[31]!=b[31] but result[31] == b[31]
  always_comb begin
    case (alu_control)
      ALU_ADD: ovf = (~a[XLEN-1] & ~b[XLEN-1] &  result[XLEN-1])
                   | ( a[XLEN-1] &  b[XLEN-1] & ~result[XLEN-1]);
      ALU_SUB: ovf = (~a[XLEN-1] &  b[XLEN-1] &  result[XLEN-1])
                   | ( a[XLEN-1] & ~b[XLEN-1] & ~result[XLEN-1]);
      default: ovf = 1'b0;
    endcase
  end

endmodule
