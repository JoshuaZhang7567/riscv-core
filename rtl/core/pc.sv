import riscv_pkg::*;

module pc (input  logic             clk, reset,
           input  logic [XLEN-1:0]  pc_next,
           output logic [XLEN-1:0]  pc_out);

  // PC register — latches next PC on every rising clock edge
  // Resets to address 0 on reset
  always_ff @(posedge clk, posedge reset)
    if (reset) pc_out <= '0;
    else       pc_out <= pc_next;

endmodule
