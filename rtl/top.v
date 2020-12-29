`default_nettype none
module top (
    i_clk,
    i_reset
    );

    input wire i_clk, i_reset;

    //Program counter
    reg [31:0] pc;
    wire pc_src;
    wire [31:0] pc_branch;
    always @(posedge i_clk) begin
        if (i_reset) begin
            pc <= 32'b0;
        end else begin
            if (pc_src == 0) begin
                pc <= pc + 32'd4;
            end else begin
                pc <= pc_branch;
            end
            
        end
    end
    
    //Instruction memory
    wire [31:0] instruction;
    wire [4:0] rs1, rs2, rd; //register source 1, 2 and register destination
    wire [6:0] instruction_funct_7;
    wire [2:0] instruction_funct_3;
    wire [6:0] instruction_opcode;
    assign rs1 = instruction[19:15];
    assign rs2 = instruction[24:20];
    assign rd = instruction[11:7];
    assign instruction_funct_7 = instruction[31:25];
    assign instruction_funct_3 = instruction[14:12];
    assign instruction_opcode = instruction[6:0];

    memory 
    #(
        .W (32),
        .D (8)
    )
    i_mem(
    	.i_clk  (i_clk  ),
        .i_addr (pc[7:0]),
        .i_data ( 32'b0),
        .i_mem_read   (1'b1 ),
        .i_mem_write(1'b0),
        .o_data (instruction )
    );

    //Register file
    wire [31:0] write_data;
    wire register_we;
    wire [31:0] read_data_1, read_data_2;
    register_file
    register_file_i (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_read_register_1(rs1), 
        .i_read_register_2(rs2), 
        .i_write_register(rd),
        .i_write_data(write_data),
        .i_we(register_we),
        .o_read_data_1(read_data_1),
        .o_read_data_2(read_data_2)
    );

    //ALU and ALU controller
    wire [31:0] immediate;
    wire alu_src;

    wire [31:0] alu_b;
    wire [1:0] alu_op;
    wire [5:0] func_code;
    wire [3:0] alu_ctl;

    assign alu_b = (alu_src==1'b1) ? immediate : read_data_2; //mux to select what goes into ALU: immediate or a register

    alu_control u_alu_control(
    	.i_alu_op    (alu_op    ),
        .i_funct7 (instruction_funct_7 ),
        .i_funct3 (instruction_funct_3 ),
        .o_alu_ctl   (alu_ctl   )
    );

    wire [31:0] alu_out;
    wire alu_zero;
    alu u_alu(
    	.i_alu_ctl (alu_ctl ),
        .i_a       (read_data_1       ),
        .i_b       (alu_b       ),
        .o_alu_out (alu_out ),
        .o_zero    (alu_zero    )
    );
    
    //Data memory
    wire d_mem_read;
    wire d_mem_write;
    wire  [31:0] d_mem_data_out;
    memory 
    #(
        .W (32),
        .D (8)
    )
    d_mem(
    	.i_clk  (i_clk  ),
        .i_addr (alu_out[7:0] ),
        .i_data (read_data_2 ),
        .i_mem_read   (d_mem_read ),
        .i_mem_write(d_mem_write),
        .o_data (d_mem_data_out )
    );
    
    wire mem_to_reg;
    assign write_data = (mem_to_reg==1'b1) ? d_mem_data_out : alu_out; //mux to select what goes into register file write_data: d_mem output or alu output

    wire branch;
    assign pc_src = branch & alu_zero;
    control u_control(
    	.i_opcode     (instruction_opcode     ),
        .o_branch     (branch     ),
        .o_mem_read   (d_mem_read   ),
        .o_mem_to_reg (mem_to_reg ),
        .o_mem_write  (d_mem_write  ),
        .o_alu_src    (alu_src    ),
        .o_reg_write  (register_we  ),
        .o_alu_op     (alu_op     )
    );
    
endmodule