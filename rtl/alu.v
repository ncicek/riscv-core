module alu (
    i_alu_ctl,
    i_a,
    i_b,
    o_alu_out,
    o_zero
    );

    input wire [3:0] i_alu_ctl;
    input wire [31:0] i_a, i_b;
    output reg [31:0] o_alu_out;
    output wire o_zero;

    assign o_zero = (o_alu_out == 0);

    always @(i_alu_ctl, i_a, i_b) begin
        case (i_alu_ctl)
            0: o_alu_out = i_a & i_b;
            1: o_alu_out = i_a | i_b;
            2: o_alu_out = i_a + i_b;
            6: o_alu_out = i_a - i_b;
            7: o_alu_out = i_a < i_b ? 32'b1 : 32'b0;
            12: o_alu_out = ~(i_a | i_b);
            default o_alu_out = 32'b0;
        endcase
    end
endmodule

module alu_control (
    i_alu_op,
    i_funct7,
    i_funct3,
    o_alu_ctl
    );

    input wire [1:0] i_alu_op;
    input wire [6:0] i_funct7;
    input wire [2:0] i_funct3;
    output reg [3:0] o_alu_ctl;

    //Figure 4.13, alu_op can never be 0b11
    wire [11:0] concat_inputs;
    assign concat_inputs = {i_alu_op, i_funct7, i_funct3};
    always casez (concat_inputs)
        12'b00zzzzzzzzzz: o_alu_ctl = 4'b0010;
        12'b01zzzzzzzzzz: o_alu_ctl = 4'b0110;
        12'b100000000000: o_alu_ctl = 4'b0010;
        12'b100100000000: o_alu_ctl = 4'b0110;
        12'b100000000111: o_alu_ctl = 4'b0000;
        12'b100000000110: o_alu_ctl = 4'b0001;
        default o_alu_ctl = 4'b0000;
    endcase
    
endmodule