module memory (
    i_clk,
    i_addr,
    i_data,
    i_mem_read,
    i_mem_write,
    o_data
    );

    parameter W=32, D=8;

    input wire i_clk;
    input wire [D-1:0] i_addr;
    input wire [W-1:0] i_data;
    input wire i_mem_read, i_mem_write;
    output reg [W-1:0] o_data = {W{1'b0}};

    reg [W-1:0] mem_array [0:(2**8-1)];

    always @(posedge i_clk) begin
        if (i_mem_write) begin //write
            mem_array[i_addr] <= i_data;
        if (i_mem_read)
            o_data <= mem_array[i_addr];
        end
    end
endmodule