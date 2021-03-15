module control (
    i_clk,
    i_reset,
    i_opcode,
    o_pc_write,
    o_pc_write_cond,
    o_i_or_d,
    o_mem_read,
    o_mem_write,
    o_ir_write,
    o_mem_to_reg,
    o_reg_write,
    o_reg_dst,
    o_alu_src_a,
    o_alu_src_b,
    o_alu_op,
    o_pc_src
    );

    input wire [6:0] i_opcode;
    output wire o_pc_write,
                o_pc_write_cond,
                o_i_or_d,
                o_mem_read,
                o_mem_write,
                o_ir_write,
                o_mem_to_reg,
                o_reg_write,
                o_reg_dst;
    output wire o_alu_src_a;
    output wire [1:0] o_alu_src_b;
    output wire [1:0] o_alu_op;
    output wire [1:0] o_pc_src;

    //state names
    parameter   instruction_fetch = 0, 
                instruction_decode_and_register_fetch = 1, 
                memory_address_computation = 2, 
                memory_access_lw = 3, 
                write_back_step = 4,
                memory_access_sw = 5,
                execution = 6,
                r_type_completion = 7,
                branch_completion = 8,
                jump_completion = 9,
                trap_state = 15;
    
    reg [3:0] state;

    always @(posedge i_clk, posedge i_reset) begin
        if (i_reset) begin
            state <= instruction_fetch;
        end else begin
            case (state)
                instruction_fetch:  
                    state <= instruction_decode_and_register_fetch;
                instruction_decode_and_register_fetch:  
                    if (i_opcode == 'lw' || i_opcode == 'sw') begin
                        state <= memory_address_computation;
                    end else if (i_opcode == 'r_type') begin
                        state <= execution;
                    end else if (i_opcode == 'beq') begin
                        state <= branch_completion;
                    end else if (i_opcode == 'j') begin
                        state <= jump_completion;
                    end else begin
                        state <= trap_state;
                    end
                memory_address_computation:  
                    if (i_opcode == 'lw') begin
                        state <= memory_access_lw;
                    end else if (i_opcode == 'sw') begin
                        state <= memory_access_sw;
                    end else begin
                        state <= trap_state;
                    end
                memory_access_lw:  
                    state <= write_back_step;
                memory_access_sw:  
                    state <= instruction_fetch;
                write_back_step:
                    state <= instruction_fetch;
                execution:
                    state <= r_type_completion;
                r_type_completion:
                    state <= instruction_fetch;
                branch_completion:
                    state <= instruction_fetch;
                jump_completion:
                    state <= instruction_fetch;
                trap_state:
                    state <= trap_state;
                default:
                    state <= trap_state;
            endcase
        end
    end

    assign o_pc_write = (state == instruction_fetch) || (state == jump_completion);
    assign o_pc_write_cond = (state == branch_completion);
    assign o_i_or_d = (state == memory_access_lw) || (state == memory_access_sw);
    assign o_mem_read = (state == instruction_fetch) || (state == memory_access_lw);
    assign o_mem_write = (state == memory_access_sw);
    assign o_ir_write = (state == instruction_fetch);
    assign o_mem_to_reg = (state == write_back_step);
    assign o_reg_write = (state == write_back_step) || (state == r_type_completion)
    assign o_reg_dst = (state == r_type_completion);


endmodule