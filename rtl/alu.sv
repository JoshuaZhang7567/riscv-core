`timescale 1ns / 1ps
import riscv_pkg::*;


module alu (    // defines the I/O pins of the ALU
    input  word_t    a,         
    input  word_t    b,         
    input  alu_op_t  alu_op,    
    output word_t    result,  
    output logic     zero       
); 

    
    always_comb begin   // always_comb block states intent to model combinational logic
        case (alu_op)   // matches the selected operation (alu_op) with the operation
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            default:  result = 32'b0;   // default to 0 for safety net
        endcase
    end

    assign zero = (result == 32'b0);    // if the result is 0, zero = 1

endmodule