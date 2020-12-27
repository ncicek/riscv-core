module alu (
    i_alu_ctl,
    i_a;
    i_b,
    o_alu_out,
    o_zero
    );

    input wire [3:0] i_alu_ctl;
    input wire [31:0] i_a, i_b;
    output wire [31:0] o_alu_out;
    output wire o_zero;

    assign o_zero = (o_alu_out == 0);

    always @(i_alu_ctl, i_a, i_b) begin
        case (i_alu_ctl)
            0: o_alu_out = i_a & i_b;
            1: o_alu_out = i_a | i_b;
            2: o_alu_out = i_a + i_b;
            6: o_alu_out = i_a - i_b 
            7: o_alu_out = i_a < i_b ? 32'b1 : 32'b0;
            12: o_alu_out = ~(i_a | i_b);
            default o_alu_out = 32'b0;
        endcase
    end
endmodule

module alu_control (
    i_alu_op,
    i_func_code,
    o_alu_ctl
    );

    input wire [1:0] i_alu_op;
    input wire [5:0] i_func_code;
    output reg [3:0]

endmodule