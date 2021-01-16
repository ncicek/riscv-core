`default_nettype none
module control (
    i_opcode,
    o_branch,
    o_mem_read,
    o_mem_to_reg,
    o_alu_op,
    o_mem_write,
    o_alu_src,
    o_reg_write
    );

    input wire [6:0] i_opcode;
    output wire o_branch, o_mem_read, o_mem_to_reg, o_mem_write, o_alu_src, o_reg_write;
    output wire [1:0] o_alu_op;

    //Figure 4.22
	reg [7:0] concated_outputs;
    //assign concated_outputs = {o_alu_src, o_mem_to_reg, o_reg_write, o_mem_read, o_mem_write, o_branch, o_alu_op};
    assign o_alu_src = concated_outputs[7];
    assign o_mem_to_reg = concated_outputs[6];
    assign o_reg_write = concated_outputs[5];
    assign o_mem_read = concated_outputs[4];
    assign o_mem_write = concated_outputs[3];
    assign o_branch = concated_outputs[2];
    assign o_alu_op = concated_outputs[1:0];
    always case (i_opcode)
        7'b0110011: concated_outputs = 8'b00100010; //r-format
        7'b0000011: concated_outputs = 8'b11110000; //ld
        7'b0100011: concated_outputs = 8'b1x001000; //sd
        7'b1100011: concated_outputs = 8'b0x000101; //beq
        default concated_outputs = 8'bxxxxxxxx;
    endcase
    
endmodule

module forwarding_unit (
    i_ex_mem_pipeline_reg_write,
    i_ex_mem_pipeline_rd,
    i_id_ex_pipeline_rs1,
    i_id_ex_pipeline_rs2,
    i_mem_wb_pipeline_reg_write,
    i_mem_wb_pipeline_rd,
    o_forward_a_muxsel,
    o_forward_b_muxsel
    );

    input wire i_ex_mem_pipeline_reg_write;
    input wire [4:0] i_id_ex_pipeline_rs1, i_id_ex_pipeline_rs2;
    input wire [4:0] i_ex_mem_pipeline_rd;
    input wire [4:0] i_mem_wb_pipeline_rd;
    input wire i_mem_wb_pipeline_reg_write;

    output reg [1:0] o_forward_a_muxsel, o_forward_b_muxsel;

    //forwarding conditions from Fig 4.53
    //ALU A input mux
    always @(*) begin
        if ((i_ex_mem_pipeline_reg_write == 1'b1) && (i_ex_mem_pipeline_rd != 5'b0) && (i_ex_mem_pipeline_rd == i_id_ex_pipeline_rs1)) begin
            o_forward_a_muxsel = 2'b10; //forward the ex_mem stage value into ALU
        end else if ((i_mem_wb_pipeline_reg_write == 1'b1) && !((i_ex_mem_pipeline_reg_write == 1'b1) && (i_ex_mem_pipeline_rd != 5'b0) && (i_ex_mem_pipeline_rd == i_id_ex_pipeline_rs1)) && (i_mem_wb_pipeline_rd == i_id_ex_pipeline_rs1)) begin
            o_forward_a_muxsel = 2'b01; //forward the mem_wb stage value into ALU
        end else begin
            o_forward_a_muxsel = 2'b00; //forward the usual id_ex stage value into ALU
        end
    end

    //ALU B input mux
    always @(*) begin
        if ((i_ex_mem_pipeline_reg_write == 1'b1) && (i_ex_mem_pipeline_rd != 5'b0) && (i_ex_mem_pipeline_rd == i_id_ex_pipeline_rs2)) begin
            o_forward_b_muxsel = 2'b10; //forward the ex_mem stage value into ALU
        end else if ((i_mem_wb_pipeline_reg_write == 1'b1) && !((i_ex_mem_pipeline_reg_write == 1'b1) && (i_ex_mem_pipeline_rd != 5'b0) && (i_ex_mem_pipeline_rd == i_id_ex_pipeline_rs2)) && (i_mem_wb_pipeline_rd == i_id_ex_pipeline_rs2)) begin
            o_forward_b_muxsel = 2'b01; //forward the mem_wb stage value into ALU
        end else begin
            o_forward_b_muxsel = 2'b00; //forward the usual id_ex stage value into ALU
        end
    end

endmodule