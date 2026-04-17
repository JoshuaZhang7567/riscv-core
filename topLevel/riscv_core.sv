module risv_core (
    input clk,
    input reset
);

    //wires
    wire [31:0] pc_current;
    wire [31:0] pc_next;
    wire [31:0] pc_plus_4;

    //next instruction address logic
    assign pc_plus_4 = pc_current + 4;
    assign pc_next = pc_plus_4;//usually, there are other options for pc_next such as jump and branch. in the future when those are implemented, a multiplexer will decide whats the next address instead of simple assignment.

    //plug in the PC module, think of instantiating an object from a class
    pc_register my_pc(
        //connects the wires of the current top level module to the pc module. the () contains the current top level wires.
        .clk(clk),
        .reset(reset),
        .pc_in(pc_next),
        .pc_out(pc_current)
    );

endmodule