/*
Data Memory Module:
- Can write or read data with RAM.
- works with following memory size/type per instruction:
        - byte (b)
        - half word (h)
        - word (w)
        - unsigned byte (bu)
        - unsigned half word (hu)
- Part of the following instructions:
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
    parameter ADDR_WIDTH = 12    // 12 bits → 4 KiB (1024 words), override at instantiation
)
(
    // inputs
    input logic [XLEN-1:0] write_data,
    input logic [XLEN-1:0] addr,

    // control signals
    input logic clk,
    input logic mem_write,
    input logic mem_read,
    input logic [2:0] funct3,

    output logic [XLEN-1:0] read_data
);
    // declare ram
    localparam DEPTH = 1 << (ADDR_WIDTH-2); // 2 to the power of (ADDR_WIDTH-2); shift binary one left (ADDR_WIDTH-2) bits. Minus 2 to the exponent is essentially divide by 4, because each row is 4 bytes.
    logic [31:0] ram [0:DEPTH-1];

    // calculate word addr, since addr is currently byte addr
    logic [ADDR_WIDTH-2-1:0] word_addr; // 2^32 bytes, so 2^30 words
    assign word_addr = addr[ADDR_WIDTH-1:2]; //drop the last 2 bits, those determine which byte within a word

    // write data logic
    always_ff @(posedge clk) begin
        if(mem_write) begin
            case (funct3)
                F3_SB: begin
                    case (addr[1:0])
                        2'b00: ram[word_addr][7:0] <= write_data[7:0];
                        2'b01: ram[word_addr][15:8] <= write_data[7:0];
                        2'b10: ram[word_addr][23:16] <= write_data[7:0];
                        2'b11: ram[word_addr][31:24] <= write_data[7:0];
                    endcase
                end
                F3_SH: begin
                    case (addr[1])
                        1'b0: ram[word_addr][15:0] <= write_data[15:0];
                        1'b1: ram[word_addr][31:16] <= write_data[15:0];
                    endcase
                end
                F3_SW: ram[word_addr] <= write_data;
                default: ;
            endcase
        end
    end

    // read data logic
    always_comb begin
        if(mem_read) begin
            case (funct3)
                F3_LB: begin
                    case (addr[1:0])
                        2'b00: read_data = {{24{ram[word_addr][7]}}, ram[word_addr][7:0]};
                        2'b01: read_data = {{24{ram[word_addr][15]}}, ram[word_addr][15:8]};
                        2'b10: read_data = {{24{ram[word_addr][23]}}, ram[word_addr][23:16]};
                        2'b11: read_data = {{24{ram[word_addr][31]}}, ram[word_addr][31:24]};
                    endcase
                end
                F3_LH: begin
                    case (addr[1])
                        1'b0: read_data = {{16{ram[word_addr][15]}}, ram[word_addr][15:0]};
                        1'b1: read_data = {{16{ram[word_addr][31]}}, ram[word_addr][31:16]};
                    endcase
                end
                F3_LW: begin
                    read_data = ram[word_addr];
                end
                F3_LBU: begin
                    case (addr[1:0])
                        2'b00: read_data = {24'b0, ram[word_addr][7:0]};
                        2'b01: read_data = {24'b0, ram[word_addr][15:8]};
                        2'b10: read_data = {24'b0, ram[word_addr][23:16]};
                        2'b11: read_data = {24'b0, ram[word_addr][31:24]};
                    endcase
                end
                F3_LHU: begin
                    case (addr[1])
                        1'b0: read_data = {16'b0, ram[word_addr][15:0]};
                        1'b1: read_data = {16'b0, ram[word_addr][31:16]};
                    endcase
                end
                default: read_data = '0;
            endcase
        end
        else read_data = '0; // output zero (turn it off) when not reading (mem_read is 0)
    end

endmodule