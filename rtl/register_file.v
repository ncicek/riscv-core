module register_file (
    i_clk,
    i_reset,
    i_read_register_1, i_read_register_2, 
    i_write_register,
    i_write_data,
    i_we,
    o_read_data_1, o_read_data_2
    );

    input wire i_clk, i_reset;
    input wire [4:0] i_read_register_1, i_read_register_2, i_write_register;
    input wire [31:0] i_write_data;
    input wire i_we;
    output reg [31:0] o_read_data_1, o_read_data_2;

    reg [31:0] x [0:31];

    integer i;
    always @(posedge i_clk) begin
        if (i_reset) begin
            for (i=0; i<32; i=i+1) begin
                x[i] <= 32'b0;
            end
        end else begin
            if (!i_we) begin
                o_read_data_1 <= x[i_read_register_1];
                o_read_data_2 <= x[i_read_register_2];
            end else begin
                if (i_write_register != 5'b0) begin //register 0 must remain 0 at all times
                    x[i_write_register] <= i_write_data;
                end
            end
        end
    end

endmodule