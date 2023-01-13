`include "/Users/weijie/Desktop/CPU2022/riscv/src/defines.v"

module ALU_RS(
    input wire clk,
    input wire rst,
    input wire rdy,

    // RsvStation
    input wire RS_input_valid,
    input wire [`OpIdBus] RS_OP_ID,
    input wire [`AddrWidth - 1 : 0] RS_inst_pc,
    input wire [`DataWidth - 1 : 0] RS_reg_rs1,
    input wire [`DataWidth - 1 : 0] RS_reg_rs2,
    input wire [`ImmWidth - 1 : 0] RS_imm,
    input wire [`ROBIDBus] RS_ROB_id,

    // ReorderBuffer
    output reg ROB_ouptut_valid,
    output reg [`ROBIDBus] ROB_ROB_id,
    output reg [`DataWidth - 1 : 0] ROB_value,
    output reg [`AddrWidth - 1 : 0] ROB_targeted_pc, // pc should to be 
    output reg ROB_jump_flag,                         // 是否要跳转

    // roll back
    input wire ROB_roll_back_flag
    
);

wire debug_input_valid;
assign debug_input_valid = RS_input_valid;
wire [`DataWidth - 1 : 0] debug_reg_rs1;
assign debug_reg_rs1 = RS_reg_rs1;
wire [`DataWidth - 1 : 0] debug_signed_reg_rs1;
assign debug_signed_reg_rs1 = $signed(RS_reg_rs1);
wire [`DataWidth - 1 : 0] debug_reg_rs2;
assign debug_reg_rs2 = RS_reg_rs2;
wire [`DataWidth - 1 : 0] debug_signed_reg_rs2;
assign debug_signed_reg_rs2 = $signed(RS_reg_rs2);
wire [`AddrWidth - 1 : 0] debug_inst_pc;
assign debug_inst_pc = RS_inst_pc;

always @(posedge clk) begin
    if(rst == `True) begin
        ROB_ouptut_valid <= `False;
    end
    else if(rdy == `False) begin
    end
    else if(ROB_roll_back_flag == `False) begin
        if(RS_input_valid == `True) begin
            ROB_ouptut_valid <= `True;
            ROB_ROB_id <= RS_ROB_id;
            if(RS_OP_ID == `LUI) begin
                ROB_value <= RS_imm;
                ROB_targeted_pc <= RS_inst_pc + 32'h4;
                ROB_jump_flag <= `False;
            end
            else if(RS_OP_ID == `AUIPC) begin
                ROB_value <= RS_inst_pc + RS_imm;
                ROB_targeted_pc <= RS_inst_pc + 32'h4;
                ROB_jump_flag <= `False;
            end
            else if(RS_OP_ID == `JAL) begin
                ROB_value <= RS_inst_pc + 32'h4;
                ROB_targeted_pc <= RS_inst_pc + RS_imm;
                ROB_jump_flag <= `True;
            end
            else if(RS_OP_ID == `JALR) begin
                ROB_value <= RS_inst_pc + 32'h4;
                ROB_targeted_pc <= RS_reg_rs1 + RS_imm;
                ROB_jump_flag <= `True;
            end
            else if(RS_OP_ID == `BEQ) begin
                ROB_value <= (RS_reg_rs1 == RS_reg_rs2);
                ROB_targeted_pc <= RS_inst_pc + RS_imm;
                ROB_jump_flag <= (RS_reg_rs1 == RS_reg_rs2) ? `True : `False;
            end
            else if(RS_OP_ID == `BNE) begin
                ROB_value <= (RS_reg_rs1 != RS_reg_rs2);
                ROB_targeted_pc <= RS_inst_pc + RS_imm;
                ROB_jump_flag <= (RS_reg_rs1 != RS_reg_rs2) ? `True : `False;
            end
            else if(RS_OP_ID == `BLT) begin
                ROB_value <= ($signed(RS_reg_rs1) < $signed(RS_reg_rs2));
                ROB_targeted_pc <= RS_inst_pc + RS_imm;
                ROB_jump_flag <= ($signed(RS_reg_rs1) < $signed(RS_reg_rs2)) ? `True : `False;
            end
            else if(RS_OP_ID == `BGE) begin
                ROB_value <= ($signed(RS_reg_rs1) >= $signed(RS_reg_rs2));
                ROB_targeted_pc <= RS_inst_pc + RS_imm;
                ROB_jump_flag <= ($signed(RS_reg_rs1) >= $signed(RS_reg_rs2)) ? `True : `False;
            end
            else if(RS_OP_ID == `BLTU) begin
                ROB_value <= (RS_reg_rs1 < RS_reg_rs2);
                ROB_targeted_pc <= RS_inst_pc + RS_imm;
                ROB_jump_flag <= (RS_reg_rs1 < RS_reg_rs2) ? `True : `False;
            end
            else if(RS_OP_ID == `BGEU) begin
                ROB_value <= (RS_reg_rs1 >= RS_reg_rs2);
                ROB_targeted_pc <= RS_inst_pc + RS_imm;
                ROB_jump_flag <= (RS_reg_rs1 >= RS_reg_rs2) ? `True : `False;
            end
            else if(RS_OP_ID == `ADD) begin
                ROB_value = RS_reg_rs1 + RS_reg_rs2;
                ROB_targeted_pc <= RS_inst_pc + 32'h4;
                ROB_jump_flag <= `False;
            end
            else if(RS_OP_ID == `SUB) begin
                ROB_value = RS_reg_rs1 - RS_reg_rs2;
                ROB_targeted_pc <= RS_inst_pc + 32'h4;
                ROB_jump_flag <= `False;
            end
            else if(RS_OP_ID == `SLL) begin
                ROB_value = RS_reg_rs1 << RS_reg_rs2;
                ROB_targeted_pc <= RS_inst_pc + 32'h4;
                ROB_jump_flag <= `False;
            end
            else if(RS_OP_ID == `SLT) begin
                ROB_value <= ($signed(RS_reg_rs1) < $signed(RS_reg_rs2));
                ROB_targeted_pc <= RS_inst_pc + 32'h4;
                ROB_jump_flag <= `False;
            end
            else if(RS_OP_ID == `SLTU) begin
                ROB_value <= (RS_reg_rs1 < RS_reg_rs2);
                ROB_targeted_pc <= RS_inst_pc + 32'h4;
                ROB_jump_flag <= `False;
            end
            else if(RS_OP_ID == `XOR) begin
                ROB_value <= RS_reg_rs1 ^ RS_reg_rs2;
                ROB_targeted_pc <= RS_inst_pc + 32'h4;
                ROB_jump_flag <= `False;
            end
            else if(RS_OP_ID == `SRL) begin
                ROB_value <= RS_reg_rs1 >> RS_reg_rs2;
                ROB_targeted_pc <= RS_inst_pc + 32'h4;
                ROB_jump_flag <= `False;
            end
            else if(RS_OP_ID == `SRA) begin
                ROB_value <= RS_reg_rs1 >>> RS_reg_rs2;
                ROB_targeted_pc <= RS_inst_pc + 32'h4;
                ROB_jump_flag <= `False;
            end
            else if(RS_OP_ID == `OR) begin
                ROB_value <= RS_reg_rs1 | RS_reg_rs2;
                ROB_targeted_pc <= RS_inst_pc + 32'h4;
                ROB_jump_flag <= `False;
            end
            else if(RS_OP_ID == `AND) begin
                ROB_value <= RS_reg_rs1 & RS_reg_rs2;
                ROB_targeted_pc <= RS_inst_pc + 32'h4;
                ROB_jump_flag <= `False;
            end
            else if(RS_OP_ID == `ADDI) begin
                ROB_value <= RS_reg_rs1 + RS_imm;
                ROB_targeted_pc <= RS_inst_pc + 32'h4;
                ROB_jump_flag <= `False;
            end
            else if(RS_OP_ID == `SLTI) begin
                ROB_value <= ($signed(RS_reg_rs1) < $signed(RS_imm));
                ROB_targeted_pc <= RS_inst_pc + 32'h4;
                ROB_jump_flag <= `False;
            end
            else if(RS_OP_ID == `SLTIU) begin
                ROB_value <= (RS_reg_rs1 < RS_imm);
                ROB_targeted_pc <= RS_inst_pc + 32'h4;
                ROB_jump_flag <= `False;
            end
            else if(RS_OP_ID == `XORI) begin
                ROB_value <= RS_reg_rs1 ^ RS_imm;
                ROB_targeted_pc <= RS_inst_pc + 32'h4;
                ROB_jump_flag <= `False;
            end
            else if(RS_OP_ID == `ORI) begin
                ROB_value <= RS_reg_rs1 | RS_imm;
                ROB_targeted_pc <= RS_inst_pc + 32'h4;
                ROB_jump_flag <= `False;
            end
            else if(RS_OP_ID == `ANDI) begin
                ROB_value <= RS_reg_rs1 & RS_imm;
                ROB_targeted_pc <= RS_inst_pc + 32'h4;
                ROB_jump_flag <= `False;
            end
            else if(RS_OP_ID == `SLLI) begin
                ROB_value <= RS_reg_rs1 << RS_imm;
                ROB_targeted_pc <= RS_inst_pc + 32'h4;
                ROB_jump_flag <= `False;
            end
            else if(RS_OP_ID == `SRLI) begin
                ROB_value <= RS_reg_rs1 >> RS_imm;
                ROB_targeted_pc <= RS_inst_pc + 32'h4;
                ROB_jump_flag <= `False;
            end
            else if(RS_OP_ID == `SRAI) begin
                ROB_value <= RS_reg_rs1 >>> RS_imm;
                ROB_targeted_pc <= RS_inst_pc + 32'h4;
                ROB_jump_flag <= `False;
            end
        end
        else begin
            ROB_ouptut_valid <= `False;
        end
    end
    else begin
        ROB_ouptut_valid <= `False;
    end
end

endmodule