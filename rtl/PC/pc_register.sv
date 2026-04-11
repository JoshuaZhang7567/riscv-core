module pc_register(
    input clk,
    input reset,
    input [31:0] pc_in,
    output reg [31:0] pc_out//reg means constant output, think of a light that is on, shows the current address
);

    always @(posedge clk or posedge reset) begin
        if (reset)//cpu is reset
            pc_out <= 32'b0;//32'b0 means a 32 bit zero
        else//not reset, normal clock tick, input gets pushed to output? <= is a non-blocking assignment, meaning update at end of current timestep.
            pc_out <= pc_in;
    end

endmodule