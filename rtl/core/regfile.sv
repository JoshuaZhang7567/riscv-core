// ============================================================================
// File:    regfile.sv
// Project: riscv-core — Single-Cycle RV32I CPU
//
// Description:
//   32-entry x 32-bit register file.
//   - Two asynchronous read ports  (rs1, rs2)
//   - One synchronous write port   (rd)
//   - x0 is hardwired to zero (writes to x0 are silently ignored)
//
// Interface matches the Harris & Harris datapath diagram:
//   a1 / rd1  →  rs1 read
//   a2 / rd2  →  rs2 read
//   a3 / wd3  →  rd  write (on rising clock edge, when we3 is asserted)
// ============================================================================

import riscv_pkg::*;

module regfile (
    input  logic                  clk,
    // Write port
    input  logic                  we3,          // Write enable
    input  logic [REG_ADDR_W-1:0] a3,           // Write address (rd)
    input  logic [XLEN-1:0]       wd3,          // Write data
    // Read port 1
    input  logic [REG_ADDR_W-1:0] a1,           // Read address (rs1)
    output logic [XLEN-1:0]       rd1,          // Read data 1
    // Read port 2
    input  logic [REG_ADDR_W-1:0] a2,           // Read address (rs2)
    output logic [XLEN-1:0]       rd2           // Read data 2
);

  logic [XLEN-1:0] rf [NUM_REGS-1:0];

  // ---- Synchronous write (x0 stays zero) ----------------------------------
  always_ff @(posedge clk) begin
    if (we3 && a3 != '0)
      rf[a3] <= wd3;
  end

  // ---- Asynchronous reads (x0 always returns 0) ---------------------------
  assign rd1 = (a1 != '0) ? rf[a1] : '0;
  assign rd2 = (a2 != '0) ? rf[a2] : '0;

endmodule
