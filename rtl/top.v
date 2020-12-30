`default_nettype none
module top (
    i_clk,
    i_reset
    );

    input wire i_clk, i_reset;

    //INSTRUCTION FETCH

    //Program counter
    reg [31:0] pc;
    wire pc_src;
    always @(posedge i_clk) begin
        if (i_reset) begin
            pc <= 32'b0;
        end else begin
            if (pc_src == 0) begin
                pc <= pc + 32'd4;
            end else begin
                pc <= ex_mem_pipeline_next_pc;
            end
            
        end
    end
    
    //Instruction memory
    wire [31:0] instruction;

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

    //IF/ID pipeline register
    reg [31:0] if_id_pipeline_pc;
    always @(posedge i_clk) begin
        if (i_reset) begin
            if_id_pipeline_pc <= 32'b0;
        end else begin
            if_id_pipeline_pc <= pc;
        end
    end

    //INSTRUCTION DECODE
    wire [4:0] instruction_rs1, instruction_rs2, instruction_rd; //register source 1, 2 and register destination

    wire [6:0] instruction_opcode;
    reg [31:0] instruction_immediate_sign_extended;
    assign instruction_rs1 = instruction[19:15];
    assign instruction_rs2 = instruction[24:20];
    assign instruction_rd = instruction[11:7];
    
    assign instruction_opcode = instruction[6:0];

    //Immediate decode and sign extend
    always @(*) begin
        casez (instruction_opcode)
            /*LOAD*/ {2'b00, 3'b000, 2'bzz}: instruction_immediate_sign_extended = {{20{instruction[31]}}, instruction[31:20]};
            /*STORE*/{2'b01, 3'b000, 2'bzz}: instruction_immediate_sign_extended = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            default: instruction_immediate_sign_extended = 32'bx;
        endcase
    end

    //Register file
    wire [31:0] write_data;
    wire [4:0] write_register;
    
    wire [31:0] read_data_1, read_data_2;
    register_file
    register_file_i (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_read_register_1(instruction_rs1), 
        .i_read_register_2(instruction_rs2), 
        .i_write_register(write_register),
        .i_write_data(write_data),
        .i_we(mem_wb_pipeline_control_reg_write),
        .o_read_data_1(read_data_1),
        .o_read_data_2(read_data_2)
    );

    wire control_branch;
    wire control_d_mem_read;
    wire control_d_mem_write;
    wire control_reg_write;
    wire control_mem_to_reg;
    wire control_alu_src;
    wire [1:0] control_alu_op;

    control u_control(
    	.i_opcode     (instruction_opcode     ),
        .o_branch     (control_branch     ),
        .o_mem_read   (control_d_mem_read   ),
        .o_mem_to_reg (control_mem_to_reg ),
        .o_mem_write  (control_d_mem_write  ),
        .o_alu_src    (control_alu_src    ),
        .o_reg_write  (control_reg_write  ),
        .o_alu_op     (control_alu_op     )
    );

    //ID/EX pipeline register
    reg [31:0] id_ex_pipeline_pc;
    reg [31:0] id_ex_pipeline_instruction;
    reg [31:0] id_ex_pipeline_instruction_immediate_sign_extended;
    reg [31:0] id_ex_pipeline_read_data_1, id_ex_pipeline_read_data_2;
    reg id_ex_pipeline_control_branch;
    reg id_ex_pipeline_control_d_mem_read;
    reg id_ex_pipeline_control_mem_to_reg;
    reg id_ex_pipeline_control_d_mem_write;
    reg id_ex_pipeline_control_alu_src;
    reg id_ex_pipeline_control_reg_write;
    reg [1:0] id_ex_pipeline_control_alu_op;

    always @(posedge i_clk) begin
        if (i_reset) begin
            id_ex_pipeline_pc <= 32'b0;
            id_ex_pipeline_instruction <= 32'b0;
            id_ex_pipeline_instruction_immediate_sign_extended <= 32'b0;
            id_ex_pipeline_read_data_1 <= 32'b0;
            id_ex_pipeline_read_data_2 <= 32'b0;
            id_ex_pipeline_control_branch <= 1'b0;
            id_ex_pipeline_control_d_mem_read <= 1'b0;
            id_ex_pipeline_control_mem_to_reg <= 1'b0;
            id_ex_pipeline_control_d_mem_write <= 1'b0;
            id_ex_pipeline_control_alu_src <= 1'b0;
            id_ex_pipeline_control_reg_write <= 1'b0;
            id_ex_pipeline_control_alu_op <= 2'b0;
        end else begin
            id_ex_pipeline_pc <= if_id_pipeline_pc;
            id_ex_pipeline_instruction <= instruction;
            id_ex_pipeline_instruction_immediate_sign_extended <= instruction_immediate_sign_extended;
            id_ex_pipeline_read_data_1 <= read_data_1;
            id_ex_pipeline_read_data_2 <= read_data_2;
            id_ex_pipeline_control_branch <= control_branch;
            id_ex_pipeline_control_d_mem_read <= control_d_mem_read;
            id_ex_pipeline_control_mem_to_reg <= control_mem_to_reg;
            id_ex_pipeline_control_d_mem_write <= control_d_mem_write;
            id_ex_pipeline_control_alu_src <= control_alu_src;
            id_ex_pipeline_control_reg_write <= control_reg_write;
            id_ex_pipeline_control_alu_op <= control_alu_op;
        end
    end

    //ALU and ALU controller
    wire [6:0] instruction_funct_7;
    wire [2:0] instruction_funct_3;
    assign instruction_funct_7 = id_ex_pipeline_instruction[31:25];
    assign instruction_funct_3 = id_ex_pipeline_instruction[14:12];
    
    wire [31:0] alu_b;
    
    wire [5:0] func_code;
    wire [3:0] alu_ctl;

    assign alu_b = (id_ex_pipeline_control_alu_src==1'b1) ? id_ex_pipeline_instruction_immediate_sign_extended : id_ex_pipeline_read_data_2; //mux to select what goes into ALU: immediate or a register

    alu_control u_alu_control(
    	.i_alu_op    (id_ex_pipeline_control_alu_op    ),
        .i_funct7 (instruction_funct_7 ),
        .i_funct3 (instruction_funct_3 ),
        .o_alu_ctl   (alu_ctl   )
    );

    wire [31:0] alu_result;
    wire alu_zero;
    alu u_alu(
    	.i_alu_ctl (alu_ctl ),
        .i_a       (id_ex_pipeline_read_data_1       ),
        .i_b       (alu_b       ),
        .o_alu_out (alu_result ),
        .o_zero    (alu_zero    )
    );
    
    wire [31:0] next_pc;
    assign next_pc = id_ex_pipeline_pc + (id_ex_pipeline_instruction_immediate_sign_extended >> 1);

    //EX/MEM pipeline register
    reg [31:0] ex_mem_pipeline_next_pc;
    reg [31:0] ex_mem_pipeline_instruction;
    reg [31:0] ex_mem_pipeline_read_data_2;
    reg [31:0] ex_mem_alu_result;
    reg ex_mem_alu_zero;
    reg ex_mem_pipeline_control_branch;
    reg ex_mem_pipeline_control_d_mem_read;
    reg ex_mem_pipeline_control_mem_to_reg;
    reg ex_mem_pipeline_control_d_mem_write;
    reg ex_mem_pipeline_control_reg_write;

    always @(posedge i_clk) begin
        if (i_reset) begin
            ex_mem_pipeline_next_pc <= 32'b0;
            ex_mem_pipeline_instruction <= 32'b0;
            ex_mem_pipeline_read_data_2 <= 32'b0;
            ex_mem_alu_result <= 32'b0;
            ex_mem_alu_zero <= 1'b0;
            ex_mem_pipeline_control_branch <= 1'b0;
            ex_mem_pipeline_control_d_mem_read <= 1'b0;
            ex_mem_pipeline_control_mem_to_reg <= 1'b0;
            ex_mem_pipeline_control_d_mem_write <= 1'b0;
            ex_mem_pipeline_control_reg_write <= 1'b0;
        end else begin
            ex_mem_pipeline_next_pc <= next_pc;
            ex_mem_pipeline_instruction <= id_ex_pipeline_instruction;
            ex_mem_pipeline_read_data_2 <= id_ex_pipeline_read_data_2;
            ex_mem_alu_result <= alu_result;
            ex_mem_alu_zero <= alu_zero;
            ex_mem_pipeline_control_branch <= id_ex_pipeline_control_branch;
            ex_mem_pipeline_control_d_mem_read <= id_ex_pipeline_control_d_mem_read;
            ex_mem_pipeline_control_mem_to_reg <= id_ex_pipeline_control_mem_to_reg;
            ex_mem_pipeline_control_d_mem_write <= id_ex_pipeline_control_d_mem_write;
            ex_mem_pipeline_control_reg_write <= id_ex_pipeline_control_reg_write;
        end
    end

    //MEMORY ACCESS
    //Data memory
    wire  [31:0] d_mem_data_out;
    memory 
    #(
        .W (32),
        .D (8)
    )
    d_mem(
    	.i_clk  (i_clk  ),
        .i_addr (ex_mem_alu_result[7:0] ),
        .i_data (ex_mem_pipeline_read_data_2 ),
        .i_mem_read   (ex_mem_pipeline_control_d_mem_read ),
        .i_mem_write(ex_mem_pipeline_control_d_mem_write),
        .o_data (d_mem_data_out )
    );
    
    assign pc_src = ex_mem_pipeline_control_branch & ex_mem_alu_zero;

    //MEM/WB pipeline register
    reg [31:0] mem_wb_pipeline_instruction;
    reg [31:0] mem_wb_mem_alu_result;
    reg mem_wb_pipeline_control_mem_to_reg;
    reg mem_wb_pipeline_control_reg_write;

    always @(posedge i_clk) begin
        if (i_reset) begin
            mem_wb_pipeline_instruction <= 32'b0;
            mem_wb_mem_alu_result <= 32'b0;
            mem_wb_pipeline_control_mem_to_reg <= 1'b0;
            mem_wb_pipeline_control_reg_write <= 1'b0;
        end else begin
            mem_wb_pipeline_instruction <= ex_mem_pipeline_instruction;
            mem_wb_mem_alu_result <= ex_mem_alu_result;
            mem_wb_pipeline_control_mem_to_reg <= ex_mem_pipeline_control_mem_to_reg;
            mem_wb_pipeline_control_reg_write <= ex_mem_pipeline_control_reg_write;
        end
    end
    
    assign write_data = (mem_wb_pipeline_control_mem_to_reg==1'b1) ? d_mem_data_out : mem_wb_mem_alu_result; //mux to select what goes into register file write_data: d_mem output or alu output
    assign write_register = mem_wb_pipeline_instruction[11:7];
    
    
    
endmodule