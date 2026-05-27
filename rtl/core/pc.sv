module pc (input  logic        clk, reset,
           input  logic [31:0] pc_next,
           output logic [31:0] pc_out);

  // PC register — latches next PC on every rising clock edge
  // Resets to address 0 on reset
  always_ff @(posedge clk, posedge reset)
    if (reset) pc_out <= 32'b0;
    else       pc_out <= pc_next;

endmodule
