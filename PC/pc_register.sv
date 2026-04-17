/*
The Program Counter(PC) will hold the instruction address of current and next clock tick. 
pc_out is outputted and becomes the current address, pc_in is the next address. pc_in is determined by logic on the top level module, such as alu +4 or a jump.
*/

module pc_register(
    input clk,
    input reset,
    input [31:0] pc_in,//replace [31:0] with word_t
    output reg [31:0] pc_out//reg means constant output, think of a light that is on, shows the current address
);

    always @(posedge clk or posedge reset) begin
        if (reset)//cpu is reset
            pc_out <= 32'b0;//32'b0 means a 32 bit zero
        else//not reset, normal clock tick, input gets pushed to output? <= is a non-blocking assignment, meaning update at end of current timestep.
            pc_out <= pc_in;
    end

endmodule