module pc (
    i_clk,
    i_reset;
    i_clock_run,
    o_pc
    );

    parameter W=32;

    input wire i_clk, i_reset, i_clock_run;
    output reg [W-1:0] o_pc = {W{1'b0}};

    reg [W-1:0] mem_array [0:(2**8-1)];

    always @(posedge i_clk) begin
        if (i_reset) begin
            o_pc <= {W{1'b0}};
        end else begin
            o_pc <= o_pc + 1'd4;
        end
    end
endmodule