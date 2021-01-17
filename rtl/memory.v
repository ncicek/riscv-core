`default_nettype none
`define NOP {12'b0, 5'b0, 3'b0, 5'b0, 7'b0010011}

module memory (
    i_clk,
    i_reset,
    i_addr, // addr must be byte aligned ie: 0 returns the first 32 bits and 4 returns the next 32 bits
    i_data,
    i_mem_read,
    i_mem_write,
    o_data
    );

    parameter W=32, D=8;

    input wire i_clk, i_reset;
    input wire [D-1:0] i_addr;
    input wire [W-1:0] i_data;
    input wire i_mem_read, i_mem_write;
    output reg [W-1:0] o_data = {W{1'b0}};

    reg [W-1:0] mem_array [0:(2**(8-2)-1)];
    wire [(D-1-2):0] byte_aligned_address = i_addr[D-1:2]; //drop 2 LSBs to get the byte address

    always @(posedge i_clk) begin
        if (i_reset) begin
            o_data <= `NOP;
        end else begin
            if (i_mem_write) begin //write
                mem_array[byte_aligned_address] <= i_data;
            end
            if (i_mem_read) begin
                o_data <= mem_array[byte_aligned_address];
            end
        end
    end
endmodule