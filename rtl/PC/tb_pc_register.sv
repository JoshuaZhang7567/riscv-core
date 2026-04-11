`timescale 1ns/1ps

module tb_pc_register();

    //create testing wires
    reg clk;
    reg reset;
    reg [31:0] pc_in;
    wire [31:0] pc_out;

    //instantiate PC
    pc_register dut( //device under test
        //plug wire and pins
        .clk(clk),//use reg for these so we can control.
        .reset(reset),
        .pc_in(pc_in),
        .pc_out(pc_out)//connect output using wire so we can observe
    );

    //create clock (flip every 5 ns)
    always #5 clk = ~clk;

    //test begins, initial runs only once
    initial begin

        //dump signals to .vcd file so i can see the waveform
        $dumpfile("pc_test.vcd");//name of file to create
        $dumpvars(0,tb_pc_register);//record all variables in this test bench

        //intialize everything
        clk = 0;
        reset = 1;
        pc_in = 0;

        //hol reset for 20ns, basically activates reset by doing that
        #20 reset = 0;

        //test case 1: give it address 4
        pc_in = 32'h00000004;
        #10;//wait for clock cycle

        //test case 2: give it address 8
        pc_in = 32'h00000008;
        #10;

        //test case 3: hit reset to see if it goes back to 0
        reset = 1;
        #10 reset = 0;

        #50 $finish;//end simulation
    end

endmodule
