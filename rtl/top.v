`default_nettype none
module top (
    i_clk,
    i_reset
    );

    input wire i_clk, i_reset;

    //INSTRUCTION FETCH

    //Program counter
    reg [31:0] pc;
    wire ex_mem_pc_src;
    always @(posedge i_clk) begin
        if (i_reset) begin
            pc <= 32'b0;
        end else begin
            if (ex_mem_pc_src == 0) begin
                pc <= pc + 32'd4;
            end else begin
                pc <= ex_mem_pipeline_next_pc;
            end
            
        end
    end
    
    //Instruction memory
    wire [31:0] if_id_pipeline_instruction;

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
        .o_data (if_id_pipeline_instruction ) //registered output
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
    wire [4:0] if_id_pipeline_instruction_rs1, if_id_pipeline_instruction_rs2, if_id_pipeline_instruction_rd; //register source 1, 2 and register destination

    wire [6:0] if_id_pipeline_instruction_opcode;
    reg [31:0] if_id_pipeline_instruction_immediate_sign_extended;
    assign if_id_pipeline_instruction_rs1 = if_id_pipeline_instruction[19:15];
    assign if_id_pipeline_instruction_rs2 = if_id_pipeline_instruction[24:20];
    assign if_id_pipeline_instruction_rd = if_id_pipeline_instruction[11:7];
    
    assign if_id_pipeline_instruction_opcode = if_id_pipeline_instruction[6:0];

    //Immediate decode and sign extend
    always @(*) begin
        casez (if_id_pipeline_instruction_opcode)
            /*LOAD*/ {2'b00, 3'b000, 2'bzz}: if_id_pipeline_instruction_immediate_sign_extended = {{20{if_id_pipeline_instruction[31]}}, if_id_pipeline_instruction[31:20]};
            /*STORE*/{2'b01, 3'b000, 2'bzz}: if_id_pipeline_instruction_immediate_sign_extended = {{20{if_id_pipeline_instruction[31]}}, if_id_pipeline_instruction[31:25], if_id_pipeline_instruction[11:7]};
            default: if_id_pipeline_instruction_immediate_sign_extended = 32'bx;
        endcase
    end

    //Register file
    wire [31:0] mem_wb_pipeline_write_data;
    wire [4:0] mem_wb_pipeline_rd;
    
    wire [31:0] id_read_data_1, id_read_data_2;
    register_file
    register_file_i (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_read_register_1(if_id_pipeline_instruction_rs1), 
        .i_read_register_2(if_id_pipeline_instruction_rs2), 
        .i_write_register(mem_wb_pipeline_rd),
        .i_write_data(mem_wb_pipeline_write_data),
        .i_we(mem_wb_pipeline_control_reg_write),
        .o_read_data_1(id_read_data_1),
        .o_read_data_2(id_read_data_2)
    );

    wire id_control_branch;
    wire id_control_d_mem_read;
    wire id_control_d_mem_write;
    wire id_control_reg_write;
    wire id_control_mem_to_reg;
    wire id_control_alu_src;
    wire [1:0] id_control_alu_op;

    control u_control(
    	.i_opcode     (if_id_pipeline_instruction_opcode     ),
        .o_branch     (id_control_branch     ),
        .o_mem_read   (id_control_d_mem_read   ),
        .o_mem_to_reg (id_control_mem_to_reg ),
        .o_mem_write  (id_control_d_mem_write  ),
        .o_alu_src    (id_control_alu_src    ),
        .o_reg_write  (id_control_reg_write  ),
        .o_alu_op     (id_control_alu_op     )
    );

    wire [1:0] forward_a_muxsel, forward_b_muxsel;
    forwarding_unit u_forwarding_unit(
    	.i_ex_mem_pipeline_reg_write (ex_mem_pipeline_control_reg_write ),
        .i_id_ex_pipeline_rs1        (id_ex_pipeline_rs1        ),
        .i_id_ex_pipeline_rs2        (id_ex_pipeline_rs2        ),
        .i_ex_mem_pipeline_rd        (ex_mem_pipeline_rd        ),
        .i_mem_wb_pipeline_rd        (mem_wb_pipeline_rd        ),
        .i_mem_wb_pipeline_reg_write (mem_wb_pipeline_control_reg_write),
        .o_forward_a_muxsel          (forward_a_muxsel          ),
        .o_forward_b_muxsel          (forward_b_muxsel          )
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

    wire [4:0] id_ex_pipeline_rs1, id_ex_pipeline_rs2;
    assign id_ex_pipeline_rs1 = id_ex_pipeline_instruction[19:15];
    assign id_ex_pipeline_rs2 = id_ex_pipeline_instruction[24:20];

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
            id_ex_pipeline_instruction <= if_id_pipeline_instruction;
            id_ex_pipeline_instruction_immediate_sign_extended <= if_id_pipeline_instruction_immediate_sign_extended;
            id_ex_pipeline_read_data_1 <= id_read_data_1;
            id_ex_pipeline_read_data_2 <= id_read_data_2;
            id_ex_pipeline_control_branch <= id_control_branch;
            id_ex_pipeline_control_d_mem_read <= id_control_d_mem_read;
            id_ex_pipeline_control_mem_to_reg <= id_control_mem_to_reg;
            id_ex_pipeline_control_d_mem_write <= id_control_d_mem_write;
            id_ex_pipeline_control_alu_src <= id_control_alu_src;
            id_ex_pipeline_control_reg_write <= id_control_reg_write;
            id_ex_pipeline_control_alu_op <= id_control_alu_op;
        end
    end

    //ALU and ALU controller
    wire [6:0] id_ex_pipeline_instruction_funct_7;
    wire [2:0] id_ex_pipeline_instruction_funct_3;
    assign id_ex_pipeline_instruction_funct_7 = id_ex_pipeline_instruction[31:25];
    assign id_ex_pipeline_instruction_funct_3 = id_ex_pipeline_instruction[14:12];
    
    wire [31:0] id_ex_alu_b;
    
    wire [3:0] ex_alu_ctl;

    assign id_ex_alu_b = (id_ex_pipeline_control_alu_src==1'b1) ? id_ex_pipeline_instruction_immediate_sign_extended : alu_b; //mux to select what goes into ALU: immediate or a register

    alu_control u_alu_control(
    	.i_alu_op    (id_ex_pipeline_control_alu_op    ),
        .i_funct7 (id_ex_pipeline_instruction_funct_7 ),
        .i_funct3 (id_ex_pipeline_instruction_funct_3 ),
        .o_alu_ctl   (ex_alu_ctl   )
    );

    //Forwarding unit selector to ALU mux
    reg [31:0] alu_a, alu_b;
    always @(*) begin
        case (forward_a_muxsel)
            2'b00: alu_a = id_ex_pipeline_read_data_1;
            2'b01: alu_a = mem_wb_pipeline_write_data;
            2'b10: alu_a = ex_mem_alu_result;
            2'b11: alu_a = 32'bx; //invalid case
        endcase

        case (forward_b_muxsel)
            2'b00: alu_b = id_ex_pipeline_read_data_2;
            2'b01: alu_b = mem_wb_pipeline_write_data;
            2'b10: alu_b = ex_mem_alu_result;
            2'b11: alu_b = 32'bx; //invalid case
        endcase
    end

    wire [31:0] ex_alu_result;
    wire ex_alu_zero;
    alu u_alu(
    	.i_alu_ctl (ex_alu_ctl ),
        .i_a       (alu_a       ),
        .i_b       (id_ex_alu_b       ),
        .o_alu_out (ex_alu_result ),
        .o_zero    (ex_alu_zero    )
    );
    
    wire [31:0] ex_next_pc;
    assign ex_next_pc = id_ex_pipeline_pc + (id_ex_pipeline_instruction_immediate_sign_extended <<< 1);

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
            ex_mem_pipeline_next_pc <= ex_next_pc;
            ex_mem_pipeline_instruction <= id_ex_pipeline_instruction;
            ex_mem_pipeline_read_data_2 <= id_ex_pipeline_read_data_2;
            ex_mem_alu_result <= ex_alu_result;
            ex_mem_alu_zero <= ex_alu_zero;
            ex_mem_pipeline_control_branch <= id_ex_pipeline_control_branch;
            ex_mem_pipeline_control_d_mem_read <= id_ex_pipeline_control_d_mem_read;
            ex_mem_pipeline_control_mem_to_reg <= id_ex_pipeline_control_mem_to_reg;
            ex_mem_pipeline_control_d_mem_write <= id_ex_pipeline_control_d_mem_write;
            ex_mem_pipeline_control_reg_write <= id_ex_pipeline_control_reg_write;
        end
    end

    wire [4:0] ex_mem_pipeline_rd;
    assign ex_mem_pipeline_rd = ex_mem_pipeline_instruction[11:7];

    //MEMORY ACCESS
    //Data memory
    wire  [31:0] mem_wb_d_mem_data_out;
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
        .o_data (mem_wb_d_mem_data_out ) //registered output
    );
    
    assign ex_mem_pc_src = ex_mem_pipeline_control_branch & ex_mem_alu_zero;

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
    
    assign mem_wb_pipeline_write_data = (mem_wb_pipeline_control_mem_to_reg==1'b1) ? mem_wb_d_mem_data_out : mem_wb_mem_alu_result; //mux to select what goes into register file write_data: d_mem output or alu output
    assign mem_wb_pipeline_rd = mem_wb_pipeline_instruction[11:7];
    
    
    
endmodule