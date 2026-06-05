/*
Data Memory Module:
- Can write or read data with RAM.
- currently only works with a full word.
- Next Steps:
    - input fun3
    - implement switch case to work with:
        - byte (b)
        - half word (h)
        - word (w)
- Finalized Module will be part of instructions:
    - lb
    - lh
    - lw
    - lbu
    - lhu

    - sb
    - sh
    - sw
*/
import riscv_pkg::*;

module dmem
#(
    parameter RAM_ADDR_WIDTH = XLEN
)
(
    input logic write_data,
    input logic addr,

    input logic clk,
    input logic mem_write,
    input logic mem_read,

    output logic read_data
);
    // declare ram
    localparam DEPTH = 1 << (ADDR_WIDTH-2) // 2 to the power of (ADDR_WIDTH-2); shift binary one left (ADDR_WIDTH-2) bits. Minus 2 to the exponent is essentially divide by 4, because each row is 4 bytes.
    logic [31:0] ram [0:DEPTH-1];

    // calculate word addr, since addr is currently byte addr
    logic [ADDR_WIDTH-2-1:0] word_addr; // 2^32 bytes, so 2^30 words
    assign word_addr = addr[ADDR_WIDTH-1:2] //drop the last 2 bits, those determine which byte within a word

    // write data logic
    always_ff @(posedge clk) begin
        if(mem_write) ram[word_addr] <= write_data;
    end

    // read data logic
    always_comb begin
        if(mem_read) read_data = ram[word_addr];
        else read_data = '0; // output zero (turn it off) when not reading (mem_read is 0)
    end

endmodule