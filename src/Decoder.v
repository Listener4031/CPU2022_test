`include "/Users/weijie/Desktop/CPU2022/riscv/src/defines.v"

module Decoder(
    input wire clk,
    input wire rst,
    input wire rdy,

    // ReorderBuffer
    input wire ROB_is_full,

    // RsvStation
    input wire RS_is_full,

    // LSBuffer
    input wire LSB_is_full,

    // InstQueue
    input wire IQ_input_valid,                    // `True -> IQ_inst could be used
    input wire [`InstWidth - 1 : 0] IQ_inst,
    input wire [`AddrWidth - 1 : 0] IQ_inst_pc,
    input wire IQ_predicted_to_jump,
    input wire [`AddrWidth - 1 : 0] IQ_predicted_pc,
    output reg IQ_enable,
    
    // LSBuffer
    output reg LSB_output_valid,
    output reg [`DataWidth - 1 : 0] LSB_inst_pc,
    output reg [`OpIdBus] LSB_OP_ID,
    output reg [`RegIndexBus] LSB_rd,
    output reg [`ImmWidth - 1 : 0] LSB_imm,

    // RegFile
    output reg RF_rd_valid,                        // from RF get ROB_id
    output reg [`RegIndexBus] RF_rd,           
    output reg RF_rs1_valid,
    output reg [`RegIndexBus] RF_rs1,
    output reg RF_rs2_valid,
    output reg [`RegIndexBus] RF_rs2,

    // RsvStation
    output reg RS_output_valid,
    output reg [`DataWidth - 1 : 0] RS_inst_pc,
    output reg [`OpIdBus] RS_OP_ID,
    output reg [`RegIndexBus] RS_rd,
    output reg [`ImmWidth - 1 : 0] RS_imm,

    // ReorderBuffer
    output reg ROB_output_valid,                    // `False -> 不进队
    output reg [`DataWidth - 1 : 0] ROB_inst_pc,
    output reg [`OpIdBus] ROB_OP_ID,
    output reg [`RegIndexBus] ROB_rd,
    output reg ROB_predicted_to_jump,
    output reg [`AddrWidth - 1 : 0] ROB_predicted_pc,

    // roll back
    input wire ROB_roll_back_flag

);

reg occupied_judger;

always @(*) begin
    IQ_enable = (occupied_judger == `False) ? `True : `False;
end

wire [`OpcodeBus] opcode;
assign opcode = (occupied_judger == `True) ? saved_inst[6 : 0] : IQ_inst[6 : 0];
wire [`Funct3Bus] funct3;
assign funct3 = (occupied_judger == `True) ? saved_inst[14 : 12] : IQ_inst[14 : 12];
wire [`Funct7Bus] funct7;
assign funct7 = (occupied_judger == `True) ? saved_inst[31 : 25] : IQ_inst[31 : 25];
wire is_LSB;
assign is_LSB = (opcode == `OPCODE_L || opcode == `OPCODE_S) ? `True : `False;

wire global_full;
assign global_full = (ROB_is_full == `True || (is_LSB == `True && LSB_is_full == `True) || (is_LSB == `False && RS_is_full == `True)) ? `True : `False;

reg [`DataWidth - 1 : 0] saved_inst;
reg [`AddrWidth - 1 : 0] saved_inst_pc;
reg saved_predicted_to_jump;
reg [`AddrWidth - 1 : 0] saved_predicted_pc;

always @(posedge clk) begin
    if(rst == `True) begin
        occupied_judger <= `False;
        saved_inst <= {32{1'b0}};
        saved_inst_pc <= {32{1'b0}};
        // LSB
        LSB_output_valid <= `False;
        // RF
        RF_rd_valid <= `False;
        RF_rs1_valid <= `False;
        RF_rs2_valid <= `False;
        // RS
        RS_output_valid <= `False;
        // ROB
        ROB_output_valid <= `False;
    end
    else if(rdy == `False) begin
    end
    else if(ROB_roll_back_flag == `False) begin
        if(global_full == `True) begin
            if(IQ_input_valid == `True && occupied_judger != `False) begin
                $display("ccc");
            end
            if(IQ_input_valid == `True) begin // occupied_judger must be `False
                occupied_judger <= `True;
                saved_inst <= IQ_inst;
                saved_inst_pc <= IQ_inst_pc;
                saved_predicted_to_jump <= IQ_predicted_to_jump;
                saved_predicted_pc <= IQ_predicted_pc;
                // LSB
                LSB_output_valid <= `False;
                // RF
                RF_rd_valid <= `False;
                RF_rs1_valid <= `False;
                RF_rs2_valid <= `False;
                // RS
                RS_output_valid <= `False;
                // ROB
                ROB_output_valid <= `False;
            end
            else begin
                // LSB
                LSB_output_valid <= `False;
                // RF
                RF_rd_valid <= `False;
                RF_rs1_valid <= `False;
                RF_rs2_valid <= `False;
                // RS
                RS_output_valid <= `False;
                // ROB
                ROB_output_valid <= `False;
            end
        end
        else begin
            if(IQ_input_valid == `True) begin
                if(occupied_judger == `True) begin
                    saved_inst <= IQ_inst;
                    saved_inst_pc <= IQ_inst_pc;
                    saved_predicted_to_jump <= IQ_predicted_to_jump;
                    saved_predicted_pc <= IQ_predicted_pc;
                    // launch saved
                    if(opcode == `OPCODE_LUI) begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `True;
                        RF_rd <= saved_inst[11 : 7];
                        RF_rs1_valid <= `False;
                        RF_rs2_valid <= `False;
                        // RS
                        RS_output_valid <= `True;
                        RS_inst_pc <= saved_inst_pc;
                        RS_OP_ID <= `LUI;
                        RS_rd <= saved_inst[11 : 7];
                        RS_imm <= {saved_inst[31 : 12], {12{1'b0}}};
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= saved_inst_pc;
                        ROB_OP_ID <= `LUI;
                        ROB_rd <= saved_inst[11 : 7];
                        ROB_predicted_to_jump <= `False;
                        ROB_predicted_pc <= saved_inst_pc + 32'h4;
                    end
                    else if(opcode == `OPCODE_AUIPC) begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `True;
                        RF_rd <= saved_inst[11 : 7];
                        RF_rs1_valid <= `False;
                        RF_rs2_valid <= `False;
                        // RS
                        RS_output_valid <= `True;
                        RS_inst_pc <= saved_inst_pc;
                        RS_OP_ID <= `AUIPC;
                        RS_rd <= saved_inst[11 : 7];
                        RS_imm <= {saved_inst[31 : 12], {12{1'b0}}};
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= saved_inst_pc;
                        ROB_OP_ID <= `AUIPC;
                        ROB_rd <= saved_inst[11 : 7];
                        ROB_predicted_to_jump <= `False;
                        ROB_predicted_pc <= saved_inst_pc + 32'h4;
                    end
                    else if(opcode == `OPCODE_JAL) begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `True;
                        RF_rd <= saved_inst[11 : 7];
                        RF_rs1_valid <= `False;
                        RF_rs2_valid <= `False;
                        // RS
                        RS_output_valid <= `True;
                        RS_inst_pc <= saved_inst_pc;
                        RS_OP_ID <= `JAL;
                        RS_rd <= saved_inst[11 : 7];
                        RS_imm <= {{12{saved_inst[31]}}, saved_inst[19:12], saved_inst[20], saved_inst[30:21], 1'b0};
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= saved_inst_pc;
                        ROB_OP_ID <= `JAL;
                        ROB_rd <= saved_inst[11 : 7];
                        ROB_predicted_to_jump <= saved_predicted_to_jump;
                        ROB_predicted_pc <= saved_predicted_pc;
                    end
                    else if(opcode == `OPCODE_JALR) begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `True;
                        RF_rd <= saved_inst[11 : 7];
                        RF_rs1_valid <= `True;
                        RF_rs1 <= saved_inst[19 : 15];
                        RF_rs2_valid <= `False;
                        // RS
                        RS_output_valid <= `True;
                        RS_inst_pc <= saved_inst_pc;
                        RS_OP_ID <= `JALR;
                        RS_rd <= saved_inst[11 : 7];
                        RS_imm <= {{20{saved_inst[31]}}, saved_inst[31 : 20]};
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= saved_inst_pc;
                        ROB_OP_ID <= `JALR;
                        ROB_rd <= saved_inst[11 : 7];
                        ROB_predicted_to_jump <= saved_predicted_to_jump;
                        ROB_predicted_pc <= saved_predicted_pc;
                    end
                    else if(opcode == `OPCODE_B) begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `False;
                        RF_rs1_valid <= `True;
                        RF_rs1 <= saved_inst[19 : 15];
                        RF_rs2_valid <= `True;
                        RF_rs2 <= saved_inst[24 : 20];
                        // RS
                        RS_output_valid <= `True;
                        RS_inst_pc <= saved_inst_pc;
                        RS_rd <= 5'b00000;
                        RS_imm <= {{20{saved_inst[31]}}, saved_inst[7], saved_inst[30:25], saved_inst[11:8], 1'b0};
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= saved_inst_pc;
                        ROB_rd <= 5'b00000;
                        ROB_predicted_to_jump <= saved_predicted_to_jump;
                        ROB_predicted_pc <= saved_predicted_pc;
                        if(funct3 == `FUNCT3_BEQ) begin
                            RS_OP_ID <= `BEQ;
                            ROB_OP_ID <= `BEQ;
                        end
                       else if(funct3 == `FUNCT3_BNE) begin
                            RS_OP_ID <= `BNE;
                            ROB_OP_ID <= `BNE;
                        end
                        else if(funct3 == `FUNCT3_BLT) begin
                            RS_OP_ID <= `BLT;
                            ROB_OP_ID <= `BLT;
                        end
                        else if(funct3 == `FUNCT3_BGE) begin
                            RS_OP_ID <= `BGE;
                            ROB_OP_ID <= `BGE;
                        end
                        else if(funct3 == `FUNCT3_BLTU) begin
                            RS_OP_ID <= `BLTU;
                            ROB_OP_ID <= `BLTU;
                        end
                        else if(funct3 == `FUNCT3_BGEU) begin
                            RS_OP_ID <= `BGEU;
                            ROB_OP_ID <= `BGEU;
                        end
                    end     
                    else if(opcode == `OPCODE_L) begin
                        // LSB
                        LSB_output_valid <= `True;
                        LSB_inst_pc <= saved_inst_pc;
                        LSB_rd <= saved_inst[11 : 7];
                        LSB_imm <= {{20{saved_inst[31]}}, saved_inst[31:20]};
                        // RF
                        RF_rd_valid <= `True;
                        RF_rd <= saved_inst[11 : 7];
                        RF_rs1_valid <= `True;
                        RF_rs1 <= saved_inst[19 : 15];
                        RF_rs2_valid <= `False;
                        // RS
                        RS_output_valid <= `False;
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= saved_inst_pc;
                        ROB_rd <= saved_inst[11 : 7];
                        ROB_predicted_to_jump <= `False;
                        ROB_predicted_pc <= saved_inst_pc + 32'h4;
                        if(funct3 == `FUNCT3_LB) begin
                            LSB_OP_ID <= `LB;
                            ROB_OP_ID <= `LB;
                        end
                        else if(funct3 == `FUNCT3_LH) begin
                            LSB_OP_ID <= `LH;
                            ROB_OP_ID <= `LH;
                        end
                        else if(funct3 == `FUNCT3_LW) begin
                            LSB_OP_ID <= `LW;
                            ROB_OP_ID <= `LW;
                        end
                        else if(funct3 == `FUNCT3_LBU) begin
                            LSB_OP_ID <= `LBU;
                            ROB_OP_ID <= `LBU;
                        end
                        else if(funct3 == `FUNCT3_LHU) begin
                            LSB_OP_ID <= `LHU;
                            ROB_OP_ID <= `LHU;
                        end
                    end
                    else if(opcode == `OPCODE_S) begin
                        // LSB
                        LSB_output_valid <= `True;
                        LSB_inst_pc <= saved_inst_pc;
                        LSB_rd <= 5'b00000;
                        LSB_imm <= {{20{saved_inst[31]}}, saved_inst[31 : 25], saved_inst[11 : 7]};
                        // RF
                        RF_rd_valid <= `False;
                        RF_rs1_valid <= `True;
                        RF_rs1 <= saved_inst[19 : 15];
                        RF_rs2_valid <= `True;
                        RF_rs2 <= saved_inst[24 : 20];
                        // RS
                        RS_output_valid <= `False;
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= saved_inst_pc;
                        ROB_rd <= 5'b00000;
                        ROB_predicted_to_jump <= `False;
                        ROB_predicted_pc <= saved_inst_pc + 32'h4;
                        if(funct3 == `FUNCT3_SB) begin
                            LSB_OP_ID <= `SB;
                            ROB_OP_ID <= `SB;
                        end
                        else if(funct3 == `FUNCT3_SH) begin
                            LSB_OP_ID <= `SH;
                            ROB_OP_ID <= `SH;
                        end
                        else if(funct3 == `FUNCT3_SW) begin
                            LSB_OP_ID <= `SW;
                            ROB_OP_ID <= `SW;
                       end
                    end
                    else if(opcode == `OPCODE_R) begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `True;
                        RF_rd <= saved_inst[11 : 7];
                        RF_rs1_valid <= `True;
                        RF_rs1 <= saved_inst[19 : 15];
                        RF_rs2_valid <= `True;
                        RF_rs2 <= saved_inst[24 : 20];
                        // RS
                        RS_output_valid <= `True;
                        RS_inst_pc <= saved_inst_pc;
                        RS_rd <= saved_inst[11 : 7];
                        RS_imm <= {32{1'b0}};
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= saved_inst_pc;
                        ROB_rd <= saved_inst[11 : 7];
                        ROB_predicted_to_jump <= `False;
                        ROB_predicted_pc <= saved_inst_pc + 32'h4;
                        if(funct3 == `FUNCT3_ADD) begin
                            if(funct7 == `FUNCT7_ADD) begin
                                RS_OP_ID <= `ADD;
                                ROB_OP_ID <= `ADD;
                            end
                            else if(funct7 == `FUNCT7_SUB) begin
                                RS_OP_ID <= `SUB;
                                ROB_OP_ID <= `SUB;
                            end
                        end
                        else if(funct3 == `FUNCT3_SLL) begin
                            RS_OP_ID <= `SLL;
                            ROB_OP_ID <= `SLL;
                        end
                        else if(funct3 == `FUNCT3_SLT) begin
                            RS_OP_ID <= `SLT;
                            ROB_OP_ID <= `SLT;
                        end
                        else if(funct3 == `FUNCT3_SLTU) begin
                            RS_OP_ID <= `SLTU;
                            ROB_OP_ID <= `SLTU;
                        end
                        else if(funct3 == `FUNCT3_XOR) begin
                            RS_OP_ID <= `XOR;
                            ROB_OP_ID <= `XOR;
                        end
                        else if(funct3 == `FUNCT3_SRL) begin
                            if(funct7 == `FUNCT7_SRL) begin
                                RS_OP_ID <= `SRL;
                                ROB_OP_ID <= `SRL;
                            end
                            else if(funct7 == `FUNCT7_SRA) begin
                                RS_OP_ID <= `SRA;
                                ROB_OP_ID <= `SRA;
                            end
                        end
                        else if(funct3 == `FUNCT3_OR) begin
                            RS_OP_ID <= `OR;
                            ROB_OP_ID <= `OR;
                        end
                        else if(funct3 == `FUNCT3_AND) begin
                            RS_OP_ID <= `AND;
                            ROB_OP_ID <= `AND;
                        end
                    end 
                    else if(opcode == `OPCODE_I) begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `True;
                        RF_rd <= saved_inst[11 : 7];
                        RF_rs1_valid <= `True;
                        RF_rs1 <= saved_inst[19 : 15];
                        RF_rs2_valid <= `False;
                        // RS
                        RS_output_valid <= `True;
                        RS_inst_pc <= saved_inst_pc;
                        RS_rd <= saved_inst[11 : 7];
                        if(funct3 == `FUNCT3_SLLI || funct3 == `FUNCT3_SRLI) RS_imm <= {{26{1'b0}}, saved_inst[25 : 20]};
                        else RS_imm <= {{20{saved_inst[31]}}, saved_inst[31 : 20]};
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= saved_inst_pc;
                        ROB_rd <= saved_inst[11 : 7];
                        ROB_predicted_to_jump <= `False;
                        ROB_predicted_pc <= saved_inst_pc + 32'h4;
                        if(funct3 == `FUNCT3_ADDI) begin
                            RS_OP_ID <= `ADDI;
                            ROB_OP_ID <= `ADDI;
                        end
                        else if(funct3 == `FUNCT3_SLTI) begin
                            RS_OP_ID <= `SLTI;
                            ROB_OP_ID <= `SLTI;
                        end
                        else if(funct3 == `FUNCT3_SLTIU) begin
                            RS_OP_ID <= `SLTIU;
                            ROB_OP_ID <= `SLTIU;
                        end
                        else if(funct3 == `FUNCT3_XORI) begin
                            RS_OP_ID <= `XORI;
                            ROB_OP_ID <= `XORI;
                        end
                        else if(funct3 == `FUNCT3_ORI) begin
                            RS_OP_ID <= `ORI;
                            ROB_OP_ID <= `ORI;
                        end
                        else if(funct3 == `FUNCT3_ANDI) begin
                            RS_OP_ID <= `ANDI;
                            ROB_OP_ID <= `ANDI;
                        end
                        else if(funct3 == `FUNCT3_SLLI) begin
                            RS_OP_ID <= `SLLI;
                            ROB_OP_ID <= `SLLI;
                        end
                        else if(funct3 == `FUNCT3_SRLI) begin
                            if(funct7 == `FUNCT7_SRLI) begin
                                RS_OP_ID <= `SRLI;
                                ROB_OP_ID <= `SRLI;
                            end
                            else if(funct7 == `FUNCT7_SRAI) begin
                                RS_OP_ID <= `SRAI;
                                ROB_OP_ID <= `SRAI;
                            end
                        end
                    end
                    else begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `False;
                        RF_rs1_valid <= `False;
                        RF_rs2_valid <= `False;
                        // RS
                        RS_output_valid <= `False;
                        // ROB
                        ROB_output_valid <= `False;
                    end
                end
                else begin
                    // launch IQ
                    if(opcode == `OPCODE_LUI) begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `True;
                        RF_rd <= IQ_inst[11 : 7];
                        RF_rs1_valid <= `False;
                        RF_rs2_valid <= `False;
                        // RS
                        RS_output_valid <= `True;
                        RS_inst_pc <= IQ_inst_pc;
                        RS_OP_ID <= `LUI;
                        RS_rd <= IQ_inst[11 : 7];
                        RS_imm <= {IQ_inst[31 : 12], {12{1'b0}}};
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= IQ_inst_pc;
                        ROB_OP_ID <= `LUI;
                        ROB_rd <= IQ_inst[11 : 7];
                        ROB_predicted_to_jump <= `False;
                        ROB_predicted_pc <= IQ_inst_pc + 32'h4;
                    end
                    else if(opcode == `OPCODE_AUIPC) begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `True;
                        RF_rd <= IQ_inst[11 : 7];
                        RF_rs1_valid <= `False;
                        RF_rs2_valid <= `False;
                        // RS
                        RS_output_valid <= `True;
                        RS_inst_pc <= IQ_inst_pc;
                        RS_OP_ID <= `AUIPC;
                        RS_rd <= IQ_inst[11 : 7];
                        RS_imm <= {IQ_inst[31 : 12], {12{1'b0}}};
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= IQ_inst_pc;
                        ROB_OP_ID <= `AUIPC;
                        ROB_rd <= IQ_inst[11 : 7];
                        ROB_predicted_to_jump <= `False;
                        ROB_predicted_pc <= IQ_inst_pc + 32'h4;
                    end
                    else if(opcode == `OPCODE_JAL) begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `True;
                        RF_rd <= IQ_inst[11 : 7];
                        RF_rs1_valid <= `False;
                        RF_rs2_valid <= `False;
                        // RS
                        RS_output_valid <= `True;
                        RS_inst_pc <= IQ_inst_pc;
                        RS_OP_ID <= `JAL;
                        RS_rd <= IQ_inst[11 : 7];
                        RS_imm <= {{12{IQ_inst[31]}}, IQ_inst[19:12], IQ_inst[20], IQ_inst[30:21], 1'b0};
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= IQ_inst_pc;
                        ROB_OP_ID <= `JAL;
                        ROB_rd <= IQ_inst[11 : 7];
                        ROB_predicted_to_jump <= IQ_predicted_to_jump;
                        ROB_predicted_pc <= IQ_predicted_pc;
                    end
                    else if(opcode == `OPCODE_JALR) begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `True;
                        RF_rd <= IQ_inst[11 : 7];
                        RF_rs1_valid <= `True;
                        RF_rs1 <= IQ_inst[19 : 15];
                        RF_rs2_valid <= `False;
                        // RS
                        RS_output_valid <= `True;
                        RS_inst_pc <= IQ_inst_pc;
                        RS_OP_ID <= `JALR;
                        RS_rd <= IQ_inst[11 : 7];
                        RS_imm <= {{20{IQ_inst[31]}}, IQ_inst[31 : 20]};
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= IQ_inst_pc;
                        ROB_OP_ID <= `JALR;
                        ROB_rd <= IQ_inst[11 : 7];
                        ROB_predicted_to_jump <= IQ_predicted_to_jump;
                        ROB_predicted_pc <= IQ_predicted_pc;
                    end
                    else if(opcode == `OPCODE_B) begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `False;
                        RF_rs1_valid <= `True;
                        RF_rs1 <= IQ_inst[19 : 15];
                        RF_rs2_valid <= `True;
                        RF_rs2 <= IQ_inst[24 : 20];
                        // RS
                        RS_output_valid <= `True;
                        RS_inst_pc <= IQ_inst_pc;
                        RS_rd <= 5'b00000;
                        RS_imm <= {{20{IQ_inst[31]}}, IQ_inst[7], IQ_inst[30:25], IQ_inst[11:8], 1'b0};
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= IQ_inst_pc;
                        ROB_rd <= 5'b00000;
                        ROB_predicted_to_jump <= IQ_predicted_to_jump;
                        ROB_predicted_pc <= IQ_predicted_pc;
                        if(funct3 == `FUNCT3_BEQ) begin
                            RS_OP_ID <= `BEQ;
                            ROB_OP_ID <= `BEQ;
                        end
                       else if(funct3 == `FUNCT3_BNE) begin
                            RS_OP_ID <= `BNE;
                            ROB_OP_ID <= `BNE;
                        end
                        else if(funct3 == `FUNCT3_BLT) begin
                            RS_OP_ID <= `BLT;
                            ROB_OP_ID <= `BLT;
                        end
                        else if(funct3 == `FUNCT3_BGE) begin
                            RS_OP_ID <= `BGE;
                            ROB_OP_ID <= `BGE;
                        end
                        else if(funct3 == `FUNCT3_BLTU) begin
                            RS_OP_ID <= `BLTU;
                            ROB_OP_ID <= `BLTU;
                        end
                        else if(funct3 == `FUNCT3_BGEU) begin
                            RS_OP_ID <= `BGEU;
                            ROB_OP_ID <= `BGEU;
                        end
                    end     
                    else if(opcode == `OPCODE_L) begin
                        // LSB
                        LSB_output_valid <= `True;
                        LSB_inst_pc <= IQ_inst_pc;
                        LSB_rd <= IQ_inst[11 : 7];
                        LSB_imm <= {{20{IQ_inst[31]}}, IQ_inst[31:20]};
                        // RF
                        RF_rd_valid <= `True;
                        RF_rd <= IQ_inst[11 : 7];
                        RF_rs1_valid <= `True;
                        RF_rs1 <= IQ_inst[19 : 15];
                        RF_rs2_valid <= `False;
                        // RS
                        RS_output_valid <= `False;
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= IQ_inst_pc;
                        ROB_rd <= IQ_inst[11 : 7];
                        ROB_predicted_to_jump <= `False;
                        ROB_predicted_pc <= IQ_inst_pc + 32'h4;
                        if(funct3 == `FUNCT3_LB) begin
                            LSB_OP_ID <= `LB;
                            ROB_OP_ID <= `LB;
                        end
                        else if(funct3 == `FUNCT3_LH) begin
                            LSB_OP_ID <= `LH;
                            ROB_OP_ID <= `LH;
                        end
                        else if(funct3 == `FUNCT3_LW) begin
                            LSB_OP_ID <= `LW;
                            ROB_OP_ID <= `LW;
                        end
                        else if(funct3 == `FUNCT3_LBU) begin
                            LSB_OP_ID <= `LBU;
                            ROB_OP_ID <= `LBU;
                        end
                        else if(funct3 == `FUNCT3_LHU) begin
                            LSB_OP_ID <= `LHU;
                            ROB_OP_ID <= `LHU;
                        end
                    end
                    else if(opcode == `OPCODE_S) begin
                        // LSB
                        LSB_output_valid <= `True;
                        LSB_inst_pc <= IQ_inst_pc;
                        LSB_rd <= 5'b00000;
                        LSB_imm <= {{20{IQ_inst[31]}}, IQ_inst[31 : 25], IQ_inst[11 : 7]};
                        // RF
                        RF_rd_valid <= `False;
                        RF_rs1_valid <= `True;
                        RF_rs1 <= IQ_inst[19 : 15];
                        RF_rs2_valid <= `True;
                        RF_rs2 <= IQ_inst[24 : 20];
                        // RS
                        RS_output_valid <= `False;
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= IQ_inst_pc;
                        ROB_rd <= 5'b00000;
                        ROB_predicted_to_jump <= `False;
                        ROB_predicted_pc <= IQ_inst_pc + 32'h4;
                        if(funct3 == `FUNCT3_SB) begin
                            LSB_OP_ID <= `SB;
                            ROB_OP_ID <= `SB;
                        end
                        else if(funct3 == `FUNCT3_SH) begin
                            LSB_OP_ID <= `SH;
                            ROB_OP_ID <= `SH;
                        end
                        else if(funct3 == `FUNCT3_SW) begin
                            LSB_OP_ID <= `SW;
                            ROB_OP_ID <= `SW;
                       end
                    end
                    else if(opcode == `OPCODE_R) begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `True;
                        RF_rd <= IQ_inst[11 : 7];
                        RF_rs1_valid <= `True;
                        RF_rs1 <= IQ_inst[19 : 15];
                        RF_rs2_valid <= `True;
                        RF_rs2 <= IQ_inst[24 : 20];
                        // RS
                        RS_output_valid <= `True;
                        RS_inst_pc <= IQ_inst_pc;
                        RS_rd <= IQ_inst[11 : 7];
                        RS_imm <= {32{1'b0}};
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= IQ_inst_pc;
                        ROB_rd <= IQ_inst[11 : 7];
                        ROB_predicted_to_jump <= `False;
                        ROB_predicted_pc <= IQ_inst_pc + 32'h4;
                        if(funct3 == `FUNCT3_ADD) begin
                            if(funct7 == `FUNCT7_ADD) begin
                                RS_OP_ID <= `ADD;
                                ROB_OP_ID <= `ADD;
                            end
                            else if(funct7 == `FUNCT7_SUB) begin
                                RS_OP_ID <= `SUB;
                                ROB_OP_ID <= `SUB;
                            end
                        end
                        else if(funct3 == `FUNCT3_SLL) begin
                            RS_OP_ID <= `SLL;
                            ROB_OP_ID <= `SLL;
                        end
                        else if(funct3 == `FUNCT3_SLT) begin
                            RS_OP_ID <= `SLT;
                            ROB_OP_ID <= `SLT;
                        end
                        else if(funct3 == `FUNCT3_SLTU) begin
                            RS_OP_ID <= `SLTU;
                            ROB_OP_ID <= `SLTU;
                        end
                        else if(funct3 == `FUNCT3_XOR) begin
                            RS_OP_ID <= `XOR;
                            ROB_OP_ID <= `XOR;
                        end
                        else if(funct3 == `FUNCT3_SRL) begin
                            if(funct7 == `FUNCT7_SRL) begin
                                RS_OP_ID <= `SRL;
                                ROB_OP_ID <= `SRL;
                            end
                            else if(funct7 == `FUNCT7_SRA) begin
                                RS_OP_ID <= `SRA;
                                ROB_OP_ID <= `SRA;
                            end
                        end
                        else if(funct3 == `FUNCT3_OR) begin
                            RS_OP_ID <= `OR;
                            ROB_OP_ID <= `OR;
                        end
                        else if(funct3 == `FUNCT3_AND) begin
                            RS_OP_ID <= `AND;
                            ROB_OP_ID <= `AND;
                        end
                    end 
                    else if(opcode == `OPCODE_I) begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `True;
                        RF_rd <= IQ_inst[11 : 7];
                        RF_rs1_valid <= `True;
                        RF_rs1 <= IQ_inst[19 : 15];
                        RF_rs2_valid <= `False;
                        // RS
                        RS_output_valid <= `True;
                        RS_inst_pc <= IQ_inst_pc;
                        RS_rd <= IQ_inst[11 : 7];
                        if(funct3 == `FUNCT3_SLLI || funct3 == `FUNCT3_SRLI) RS_imm <= {{26{1'b0}}, IQ_inst[25 : 20]};
                        else RS_imm <= {{20{IQ_inst[31]}}, IQ_inst[31 : 20]};
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= IQ_inst_pc;
                        ROB_rd <= IQ_inst[11 : 7];
                       ROB_predicted_to_jump <= `False;
                       ROB_predicted_pc <= IQ_inst_pc + 32'h4;
                        if(funct3 == `FUNCT3_ADDI) begin
                            RS_OP_ID <= `ADDI;
                            ROB_OP_ID <= `ADDI;
                        end
                        else if(funct3 == `FUNCT3_SLTI) begin
                            RS_OP_ID <= `SLTI;
                            ROB_OP_ID <= `SLTI;
                        end
                        else if(funct3 == `FUNCT3_SLTIU) begin
                            RS_OP_ID <= `SLTIU;
                            ROB_OP_ID <= `SLTIU;
                        end
                        else if(funct3 == `FUNCT3_XORI) begin
                            RS_OP_ID <= `XORI;
                            ROB_OP_ID <= `XORI;
                        end
                        else if(funct3 == `FUNCT3_ORI) begin
                            RS_OP_ID <= `ORI;
                            ROB_OP_ID <= `ORI;
                        end
                        else if(funct3 == `FUNCT3_ANDI) begin
                            RS_OP_ID <= `ANDI;
                            ROB_OP_ID <= `ANDI;
                        end
                        else if(funct3 == `FUNCT3_SLLI) begin
                            RS_OP_ID <= `SLLI;
                            ROB_OP_ID <= `SLLI;
                        end
                       else if(funct3 == `FUNCT3_SRLI) begin
                            if(funct7 == `FUNCT7_SRLI) begin
                                RS_OP_ID <= `SRLI;
                                ROB_OP_ID <= `SRLI;
                            end
                            else if(funct7 == `FUNCT7_SRAI) begin
                                RS_OP_ID <= `SRAI;
                                ROB_OP_ID <= `SRAI;
                            end
                        end
                    end
                    else begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `False;
                        RF_rs1_valid <= `False;
                        RF_rs2_valid <= `False;
                        // RS
                        RS_output_valid <= `False;
                        // ROB
                        ROB_output_valid <= `False;
                    end
                end
            end
            else begin
                if(occupied_judger == `True) begin
                    occupied_judger <= `False;
                    // launch saved
                    if(opcode == `OPCODE_LUI) begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `True;
                        RF_rd <= saved_inst[11 : 7];
                        RF_rs1_valid <= `False;
                        RF_rs2_valid <= `False;
                        // RS
                        RS_output_valid <= `True;
                        RS_inst_pc <= saved_inst_pc;
                        RS_OP_ID <= `LUI;
                        RS_rd <= saved_inst[11 : 7];
                        RS_imm <= {saved_inst[31 : 12], {12{1'b0}}};
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= saved_inst_pc;
                        ROB_OP_ID <= `LUI;
                        ROB_rd <= saved_inst[11 : 7];
                        ROB_predicted_to_jump <= `False;
                        ROB_predicted_pc <= saved_inst_pc + 32'h4;
                    end
                    else if(opcode == `OPCODE_AUIPC) begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `True;
                        RF_rd <= saved_inst[11 : 7];
                        RF_rs1_valid <= `False;
                        RF_rs2_valid <= `False;
                        // RS
                        RS_output_valid <= `True;
                        RS_inst_pc <= saved_inst_pc;
                        RS_OP_ID <= `AUIPC;
                        RS_rd <= saved_inst[11 : 7];
                        RS_imm <= {saved_inst[31 : 12], {12{1'b0}}};
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= saved_inst_pc;
                        ROB_OP_ID <= `AUIPC;
                        ROB_rd <= saved_inst[11 : 7];
                        ROB_predicted_to_jump <= `False;
                        ROB_predicted_pc <= saved_inst_pc + 32'h4;
                    end
                    else if(opcode == `OPCODE_JAL) begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `True;
                        RF_rd <= saved_inst[11 : 7];
                        RF_rs1_valid <= `False;
                        RF_rs2_valid <= `False;
                        // RS
                        RS_output_valid <= `True;
                        RS_inst_pc <= saved_inst_pc;
                        RS_OP_ID <= `JAL;
                        RS_rd <= saved_inst[11 : 7];
                        RS_imm <= {{12{saved_inst[31]}}, saved_inst[19:12], saved_inst[20], saved_inst[30:21], 1'b0};
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= saved_inst_pc;
                        ROB_OP_ID <= `JAL;
                        ROB_rd <= saved_inst[11 : 7];
                        ROB_predicted_to_jump <= saved_predicted_to_jump;
                        ROB_predicted_pc <= saved_predicted_pc;
                    end
                    else if(opcode == `OPCODE_JALR) begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `True;
                        RF_rd <= saved_inst[11 : 7];
                        RF_rs1_valid <= `True;
                        RF_rs1 <= saved_inst[19 : 15];
                        RF_rs2_valid <= `False;
                        // RS
                        RS_output_valid <= `True;
                        RS_inst_pc <= saved_inst_pc;
                        RS_OP_ID <= `JALR;
                        RS_rd <= saved_inst[11 : 7];
                        RS_imm <= {{20{saved_inst[31]}}, saved_inst[31 : 20]};
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= saved_inst_pc;
                        ROB_OP_ID <= `JALR;
                        ROB_rd <= saved_inst[11 : 7];
                        ROB_predicted_to_jump <= saved_predicted_to_jump;
                        ROB_predicted_pc <= saved_predicted_pc;
                    end
                    else if(opcode == `OPCODE_B) begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `False;
                        RF_rs1_valid <= `True;
                        RF_rs1 <= saved_inst[19 : 15];
                        RF_rs2_valid <= `True;
                        RF_rs2 <= saved_inst[24 : 20];
                        // RS
                        RS_output_valid <= `True;
                        RS_inst_pc <= saved_inst_pc;
                        RS_rd <= 5'b00000;
                        RS_imm <= {{20{saved_inst[31]}}, saved_inst[7], saved_inst[30:25], saved_inst[11:8], 1'b0};
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= saved_inst_pc;
                        ROB_rd <= 5'b00000;
                        ROB_predicted_to_jump <= saved_predicted_to_jump;
                        ROB_predicted_pc <= saved_predicted_pc;
                        if(funct3 == `FUNCT3_BEQ) begin
                            RS_OP_ID <= `BEQ;
                            ROB_OP_ID <= `BEQ;
                        end
                       else if(funct3 == `FUNCT3_BNE) begin
                            RS_OP_ID <= `BNE;
                            ROB_OP_ID <= `BNE;
                        end
                        else if(funct3 == `FUNCT3_BLT) begin
                            RS_OP_ID <= `BLT;
                            ROB_OP_ID <= `BLT;
                        end
                        else if(funct3 == `FUNCT3_BGE) begin
                            RS_OP_ID <= `BGE;
                            ROB_OP_ID <= `BGE;
                        end
                        else if(funct3 == `FUNCT3_BLTU) begin
                            RS_OP_ID <= `BLTU;
                            ROB_OP_ID <= `BLTU;
                        end
                        else if(funct3 == `FUNCT3_BGEU) begin
                            RS_OP_ID <= `BGEU;
                            ROB_OP_ID <= `BGEU;
                        end
                    end     
                    else if(opcode == `OPCODE_L) begin
                        // LSB
                        LSB_output_valid <= `True;
                        LSB_inst_pc <= saved_inst_pc;
                        LSB_rd <= saved_inst[11 : 7];
                        LSB_imm <= {{20{saved_inst[31]}}, saved_inst[31:20]};
                        // RF
                        RF_rd_valid <= `True;
                        RF_rd <= saved_inst[11 : 7];
                        RF_rs1_valid <= `True;
                        RF_rs1 <= saved_inst[19 : 15];
                        RF_rs2_valid <= `False;
                        // RS
                        RS_output_valid <= `False;
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= saved_inst_pc;
                        ROB_rd <= saved_inst[11 : 7];
                        ROB_predicted_to_jump <= `False;
                        ROB_predicted_pc <= saved_inst_pc + 32'h4;
                        if(funct3 == `FUNCT3_LB) begin
                            LSB_OP_ID <= `LB;
                            ROB_OP_ID <= `LB;
                        end
                        else if(funct3 == `FUNCT3_LH) begin
                            LSB_OP_ID <= `LH;
                            ROB_OP_ID <= `LH;
                        end
                        else if(funct3 == `FUNCT3_LW) begin
                            LSB_OP_ID <= `LW;
                            ROB_OP_ID <= `LW;
                        end
                        else if(funct3 == `FUNCT3_LBU) begin
                            LSB_OP_ID <= `LBU;
                            ROB_OP_ID <= `LBU;
                        end
                        else if(funct3 == `FUNCT3_LHU) begin
                            LSB_OP_ID <= `LHU;
                            ROB_OP_ID <= `LHU;
                        end
                    end
                    else if(opcode == `OPCODE_S) begin
                        // LSB
                        LSB_output_valid <= `True;
                        LSB_inst_pc <= saved_inst_pc;
                        LSB_rd <= 5'b00000;
                        LSB_imm <= {{20{saved_inst[31]}}, saved_inst[31 : 25], saved_inst[11 : 7]};
                        // RF
                        RF_rd_valid <= `False;
                        RF_rs1_valid <= `True;
                        RF_rs1 <= saved_inst[19 : 15];
                        RF_rs2_valid <= `True;
                        RF_rs2 <= saved_inst[24 : 20];
                        // RS
                        RS_output_valid <= `False;
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= saved_inst_pc;
                        ROB_rd <= 5'b00000;
                        ROB_predicted_to_jump <= `False;
                        ROB_predicted_pc <= saved_inst_pc + 32'h4;
                        if(funct3 == `FUNCT3_SB) begin
                            LSB_OP_ID <= `SB;
                            ROB_OP_ID <= `SB;
                        end
                        else if(funct3 == `FUNCT3_SH) begin
                            LSB_OP_ID <= `SH;
                            ROB_OP_ID <= `SH;
                        end
                        else if(funct3 == `FUNCT3_SW) begin
                            LSB_OP_ID <= `SW;
                            ROB_OP_ID <= `SW;
                       end
                    end
                    else if(opcode == `OPCODE_R) begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `True;
                        RF_rd <= saved_inst[11 : 7];
                        RF_rs1_valid <= `True;
                        RF_rs1 <= saved_inst[19 : 15];
                        RF_rs2_valid <= `True;
                        RF_rs2 <= saved_inst[24 : 20];
                        // RS
                        RS_output_valid <= `True;
                        RS_inst_pc <= saved_inst_pc;
                        RS_rd <= saved_inst[11 : 7];
                        RS_imm <= {32{1'b0}};
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= saved_inst_pc;
                        ROB_rd <= saved_inst[11 : 7];
                        ROB_predicted_to_jump <= `False;
                        ROB_predicted_pc <= saved_inst_pc + 32'h4;
                        if(funct3 == `FUNCT3_ADD) begin
                            if(funct7 == `FUNCT7_ADD) begin
                                RS_OP_ID <= `ADD;
                                ROB_OP_ID <= `ADD;
                            end
                            else if(funct7 == `FUNCT7_SUB) begin
                                RS_OP_ID <= `SUB;
                                ROB_OP_ID <= `SUB;
                            end
                        end
                        else if(funct3 == `FUNCT3_SLL) begin
                            RS_OP_ID <= `SLL;
                            ROB_OP_ID <= `SLL;
                        end
                        else if(funct3 == `FUNCT3_SLT) begin
                            RS_OP_ID <= `SLT;
                            ROB_OP_ID <= `SLT;
                        end
                        else if(funct3 == `FUNCT3_SLTU) begin
                            RS_OP_ID <= `SLTU;
                            ROB_OP_ID <= `SLTU;
                        end
                        else if(funct3 == `FUNCT3_XOR) begin
                            RS_OP_ID <= `XOR;
                            ROB_OP_ID <= `XOR;
                        end
                        else if(funct3 == `FUNCT3_SRL) begin
                            if(funct7 == `FUNCT7_SRL) begin
                                RS_OP_ID <= `SRL;
                                ROB_OP_ID <= `SRL;
                            end
                            else if(funct7 == `FUNCT7_SRA) begin
                                RS_OP_ID <= `SRA;
                                ROB_OP_ID <= `SRA;
                            end
                        end
                        else if(funct3 == `FUNCT3_OR) begin
                            RS_OP_ID <= `OR;
                            ROB_OP_ID <= `OR;
                        end
                        else if(funct3 == `FUNCT3_AND) begin
                            RS_OP_ID <= `AND;
                            ROB_OP_ID <= `AND;
                        end
                    end 
                    else if(opcode == `OPCODE_I) begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `True;
                        RF_rd <= saved_inst[11 : 7];
                        RF_rs1_valid <= `True;
                        RF_rs1 <= saved_inst[19 : 15];
                        RF_rs2_valid <= `False;
                        // RS
                        RS_output_valid <= `True;
                        RS_inst_pc <= saved_inst_pc;
                        RS_rd <= saved_inst[11 : 7];
                        if(funct3 == `FUNCT3_SLLI || funct3 == `FUNCT3_SRLI) RS_imm <= {{26{1'b0}}, saved_inst[25 : 20]};
                        else RS_imm <= {{20{saved_inst[31]}}, saved_inst[31 : 20]};
                        // ROB
                        ROB_output_valid <= `True;
                        ROB_inst_pc <= saved_inst_pc;
                        ROB_rd <= saved_inst[11 : 7];
                        ROB_predicted_to_jump <= `False;
                        ROB_predicted_pc <= saved_inst_pc + 32'h4;
                        if(funct3 == `FUNCT3_ADDI) begin
                            RS_OP_ID <= `ADDI;
                            ROB_OP_ID <= `ADDI;
                        end
                        else if(funct3 == `FUNCT3_SLTI) begin
                            RS_OP_ID <= `SLTI;
                            ROB_OP_ID <= `SLTI;
                        end
                        else if(funct3 == `FUNCT3_SLTIU) begin
                            RS_OP_ID <= `SLTIU;
                            ROB_OP_ID <= `SLTIU;
                        end
                        else if(funct3 == `FUNCT3_XORI) begin
                            RS_OP_ID <= `XORI;
                            ROB_OP_ID <= `XORI;
                        end
                        else if(funct3 == `FUNCT3_ORI) begin
                            RS_OP_ID <= `ORI;
                            ROB_OP_ID <= `ORI;
                        end
                        else if(funct3 == `FUNCT3_ANDI) begin
                            RS_OP_ID <= `ANDI;
                            ROB_OP_ID <= `ANDI;
                        end
                        else if(funct3 == `FUNCT3_SLLI) begin
                            RS_OP_ID <= `SLLI;
                            ROB_OP_ID <= `SLLI;
                        end
                       else if(funct3 == `FUNCT3_SRLI) begin
                            if(funct7 == `FUNCT7_SRLI) begin
                                RS_OP_ID <= `SRLI;
                                ROB_OP_ID <= `SRLI;
                            end
                            else if(funct7 == `FUNCT7_SRAI) begin
                                RS_OP_ID <= `SRAI;
                                ROB_OP_ID <= `SRAI;
                            end
                        end
                    end
                    else begin
                        // LSB
                        LSB_output_valid <= `False;
                        // RF
                        RF_rd_valid <= `False;
                        RF_rs1_valid <= `False;
                        RF_rs2_valid <= `False;
                        // RS
                        RS_output_valid <= `False;
                        // ROB
                        ROB_output_valid <= `False;
                    end
                end
                else begin
                    // LSB
                    LSB_output_valid <= `False;
                    // RF
                    RF_rd_valid <= `False;
                    RF_rs1_valid <= `False;
                    RF_rs2_valid <= `False;
                    // RS
                    RS_output_valid <= `False;
                    // ROB
                    ROB_output_valid <= `False;
                end
            end
        end
    end
    else begin // roll back
        occupied_judger <= `False;
        saved_inst <= {32{1'b0}};
        saved_inst_pc <= {32{1'b0}};
        // LSB
        LSB_output_valid <= `False;
        // RF
        RF_rd_valid <= `False;
        RF_rs1_valid <= `False;
        RF_rs2_valid <= `False;
        // RS
        RS_output_valid <= `False;
        // ROB
        ROB_output_valid <= `False;
    end
end

endmodule

/*
if(opcode == `OPCODE_LUI) begin
            // LSB
            LSB_output_valid <= `False;
            // RF
            RF_rd_valid <= `True;
            RF_rd <= IQ_inst[11 : 7];
            RF_rs1_valid <= `False;
            RF_rs2_valid <= `False;
            // RS
            RS_output_valid <= `True;
            RS_inst_pc <= IQ_inst_pc;
            RS_OP_ID <= `LUI;
            RS_rd <= IQ_inst[11 : 7];
            RS_imm <= {IQ_inst[31 : 12], {12{1'b0}}};
            // ROB
            ROB_output_valid <= `True;
            ROB_inst_pc <= IQ_inst_pc;
            ROB_OP_ID <= `LUI;
            ROB_rd <= IQ_inst[11 : 7];
            ROB_predicted_to_jump <= `False;
            ROB_predicted_pc <= IQ_inst_pc + 32'h4;
        end
        else if(opcode == `OPCODE_AUIPC) begin
            // LSB
            LSB_output_valid <= `False;
            // RF
            RF_rd_valid <= `True;
            RF_rd <= IQ_inst[11 : 7];
            RF_rs1_valid <= `False;
            RF_rs2_valid <= `False;
            // RS
            RS_output_valid <= `True;
            RS_inst_pc <= IQ_inst_pc;
            RS_OP_ID <= `AUIPC;
            RS_rd <= IQ_inst[11 : 7];
            RS_imm <= {IQ_inst[31 : 12], {12{1'b0}}};
            // ROB
            ROB_output_valid <= `True;
            ROB_inst_pc <= IQ_inst_pc;
            ROB_OP_ID <= `AUIPC;
            ROB_rd <= IQ_inst[11 : 7];
            ROB_predicted_to_jump <= `False;
            ROB_predicted_pc <= IQ_inst_pc + 32'h4;
        end
        else if(opcode == `OPCODE_JAL) begin
            // LSB
            LSB_output_valid <= `False;
            // RF
            RF_rd_valid <= `True;
            RF_rd <= IQ_inst[11 : 7];
            RF_rs1_valid <= `False;
            RF_rs2_valid <= `False;
            // RS
            RS_output_valid <= `True;
            RS_inst_pc <= IQ_inst_pc;
            RS_OP_ID <= `JAL;
            RS_rd <= IQ_inst[11 : 7];
            RS_imm <= {{12{IQ_inst[31]}}, IQ_inst[19:12], IQ_inst[20], IQ_inst[30:21], 1'b0};
            // ROB
            ROB_output_valid <= `True;
            ROB_inst_pc <= IQ_inst_pc;
            ROB_OP_ID <= `JAL;
            ROB_rd <= IQ_inst[11 : 7];
            ROB_predicted_to_jump <= IQ_predicted_to_jump;
            ROB_predicted_pc <= IQ_predicted_pc;
        end
        else if(opcode == `OPCODE_JALR) begin
            // LSB
            LSB_output_valid <= `False;
            // RF
            RF_rd_valid <= `True;
            RF_rd <= IQ_inst[11 : 7];
            RF_rs1_valid <= `True;
            RF_rs1 <= IQ_inst[19 : 15];
            RF_rs2_valid <= `False;
            // RS
            RS_output_valid <= `True;
            RS_inst_pc <= IQ_inst_pc;
            RS_OP_ID <= `JALR;
            RS_rd <= IQ_inst[11 : 7];
            RS_imm <= {{20{IQ_inst[31]}}, IQ_inst[31 : 20]};
            // ROB
            ROB_output_valid <= `True;
            ROB_inst_pc <= IQ_inst_pc;
            ROB_OP_ID <= `JALR;
            ROB_rd <= IQ_inst[11 : 7];
            ROB_predicted_to_jump <= IQ_predicted_to_jump;
            ROB_predicted_pc <= IQ_predicted_pc;
        end
        else if(opcode == `OPCODE_B) begin
            // LSB
            LSB_output_valid <= `False;
            // RF
            RF_rd_valid <= `False;
            RF_rs1_valid <= `True;
            RF_rs1 <= IQ_inst[19 : 15];
            RF_rs2_valid <= `True;
            RF_rs2 <= IQ_inst[24 : 20];
            // RS
            RS_output_valid <= `True;
            RS_inst_pc <= IQ_inst_pc;
            RS_rd <= 5'b00000;
            RS_imm <= {{20{IQ_inst[31]}}, IQ_inst[7], IQ_inst[30:25], IQ_inst[11:8], 1'b0};
            // ROB
            ROB_output_valid <= `True;
            ROB_inst_pc <= IQ_inst_pc;
            ROB_rd <= 5'b00000;
            ROB_predicted_to_jump <= IQ_predicted_to_jump;
            ROB_predicted_pc <= IQ_predicted_pc;
            if(funct3 == `FUNCT3_BEQ) begin
                RS_OP_ID <= `BEQ;
                ROB_OP_ID <= `BEQ;
            end
            else if(funct3 == `FUNCT3_BNE) begin
                RS_OP_ID <= `BNE;
                ROB_OP_ID <= `BNE;
            end
            else if(funct3 == `FUNCT3_BLT) begin
                RS_OP_ID <= `BLT;
                ROB_OP_ID <= `BLT;
            end
            else if(funct3 == `FUNCT3_BGE) begin
                RS_OP_ID <= `BGE;
                ROB_OP_ID <= `BGE;
            end
            else if(funct3 == `FUNCT3_BLTU) begin
                RS_OP_ID <= `BLTU;
                ROB_OP_ID <= `BLTU;
            end
            else if(funct3 == `FUNCT3_BGEU) begin
                RS_OP_ID <= `BGEU;
                ROB_OP_ID <= `BGEU;
            end
        end     
        else if(opcode == `OPCODE_L) begin
            // LSB
            LSB_output_valid <= `True;
            LSB_inst_pc <= IQ_inst_pc;
            LSB_rd <= IQ_inst[11 : 7];
            LSB_imm <= {{20{IQ_inst[31]}}, IQ_inst[31:20]};
            // RF
            RF_rd_valid <= `True;
            RF_rd <= IQ_inst[11 : 7];
            RF_rs1_valid <= `True;
            RF_rs1 <= IQ_inst[19 : 15];
            RF_rs2_valid <= `False;
            // RS
            RS_output_valid <= `False;
            // ROB
            ROB_output_valid <= `True;
            ROB_inst_pc <= IQ_inst_pc;
            ROB_rd <= IQ_inst[11 : 7];
            ROB_predicted_to_jump <= `False;
            ROB_predicted_pc <= IQ_inst_pc + 32'h4;
            if(funct3 == `FUNCT3_LB) begin
                LSB_OP_ID <= `LB;
                ROB_OP_ID <= `LB;
            end
            else if(funct3 == `FUNCT3_LH) begin
                LSB_OP_ID <= `LH;
                ROB_OP_ID <= `LH;
            end
            else if(funct3 == `FUNCT3_LW) begin
                LSB_OP_ID <= `LW;
                ROB_OP_ID <= `LW;
            end
            else if(funct3 == `FUNCT3_LBU) begin
                LSB_OP_ID <= `LBU;
                ROB_OP_ID <= `LBU;
            end
            else if(funct3 == `FUNCT3_LHU) begin
                LSB_OP_ID <= `LHU;
                ROB_OP_ID <= `LHU;
            end
        end
        else if(opcode == `OPCODE_S) begin
            // LSB
            LSB_output_valid <= `True;
            LSB_inst_pc <= IQ_inst_pc;
            LSB_rd <= 5'b00000;
            LSB_imm <= {{20{IQ_inst[31]}}, IQ_inst[31 : 25], IQ_inst[11 : 7]};
            // RF
            RF_rd_valid <= `False;
            RF_rs1_valid <= `True;
            RF_rs1 <= IQ_inst[19 : 15];
            RF_rs2_valid <= `True;
            RF_rs2 <= IQ_inst[24 : 20];
            // RS
            RS_output_valid <= `False;
            // ROB
            ROB_output_valid <= `True;
            ROB_inst_pc <= IQ_inst_pc;
            ROB_rd <= 5'b00000;
            ROB_predicted_to_jump <= `False;
            ROB_predicted_pc <= IQ_inst_pc + 32'h4;
            if(funct3 == `FUNCT3_SB) begin
                LSB_OP_ID <= `SB;
                ROB_OP_ID <= `SB;
            end
            else if(funct3 == `FUNCT3_SH) begin
                LSB_OP_ID <= `SH;
                ROB_OP_ID <= `SH;
            end
            else if(funct3 == `FUNCT3_SW) begin
                LSB_OP_ID <= `SW;
                ROB_OP_ID <= `SW;
            end
        end
        else if(opcode == `OPCODE_R) begin
            // LSB
            LSB_output_valid <= `False;
            // RF
            RF_rd_valid <= `True;
            RF_rd <= IQ_inst[11 : 7];
            RF_rs1_valid <= `True;
            RF_rs1 <= IQ_inst[19 : 15];
            RF_rs2_valid <= `True;
            RF_rs2 <= IQ_inst[24 : 20];
            // RS
            RS_output_valid <= `True;
            RS_inst_pc <= IQ_inst_pc;
            RS_rd <= IQ_inst[11 : 7];
            RS_imm <= {32{1'b0}};
            // ROB
            ROB_output_valid <= `True;
            ROB_inst_pc <= IQ_inst_pc;
            ROB_rd <= IQ_inst[11 : 7];
            ROB_predicted_to_jump <= `False;
            ROB_predicted_pc <= IQ_inst_pc + 32'h4;
            if(funct3 == `FUNCT3_ADD) begin
                if(funct7 == `FUNCT7_ADD) begin
                    RS_OP_ID <= `ADD;
                    ROB_OP_ID <= `ADD;
                end
                else if(funct7 == `FUNCT7_SUB) begin
                    RS_OP_ID <= `SUB;
                    ROB_OP_ID <= `SUB;
                end
            end
            else if(funct3 == `FUNCT3_SLL) begin
                RS_OP_ID <= `SLL;
                ROB_OP_ID <= `SLL;
            end
            else if(funct3 == `FUNCT3_SLT) begin
                RS_OP_ID <= `SLT;
                ROB_OP_ID <= `SLT;
            end
            else if(funct3 == `FUNCT3_SLTU) begin
                RS_OP_ID <= `SLTU;
                ROB_OP_ID <= `SLTU;
            end
            else if(funct3 == `FUNCT3_XOR) begin
                RS_OP_ID <= `XOR;
                ROB_OP_ID <= `XOR;
            end
            else if(funct3 == `FUNCT3_SRL) begin
                if(funct7 == `FUNCT7_SRL) begin
                    RS_OP_ID <= `SRL;
                    ROB_OP_ID <= `SRL;
                end
                else if(funct7 == `FUNCT7_SRA) begin
                    RS_OP_ID <= `SRA;
                    ROB_OP_ID <= `SRA;
                end
            end
            else if(funct3 == `FUNCT3_OR) begin
                RS_OP_ID <= `OR;
                ROB_OP_ID <= `OR;
            end
            else if(funct3 == `FUNCT3_AND) begin
                RS_OP_ID <= `AND;
                ROB_OP_ID <= `AND;
            end
        end 
        else if(opcode == `OPCODE_I) begin
            // LSB
            LSB_output_valid <= `False;
            // RF
            RF_rd_valid <= `True;
            RF_rd <= IQ_inst[11 : 7];
            RF_rs1_valid <= `True;
            RF_rs1 <= IQ_inst[19 : 15];
            RF_rs2_valid <= `False;
            // RS
            RS_output_valid <= `True;
            RS_inst_pc <= IQ_inst_pc;
            RS_rd <= IQ_inst[11 : 7];
            if(funct3 == `FUNCT3_SLLI || funct3 == `FUNCT3_SRLI) RS_imm <= {{26{1'b0}}, IQ_inst[25 : 20]};
            else RS_imm <= {{20{IQ_inst[31]}}, IQ_inst[31 : 20]};
            // ROB
            ROB_output_valid <= `True;
            ROB_inst_pc <= IQ_inst_pc;
            ROB_rd <= IQ_inst[11 : 7];
            ROB_predicted_to_jump <= `False;
            ROB_predicted_pc <= IQ_inst_pc + 32'h4;
            if(funct3 == `FUNCT3_ADDI) begin
                RS_OP_ID <= `ADDI;
                ROB_OP_ID <= `ADDI;
            end
            else if(funct3 == `FUNCT3_SLTI) begin
                RS_OP_ID <= `SLTI;
                ROB_OP_ID <= `SLTI;
            end
            else if(funct3 == `FUNCT3_SLTIU) begin
                RS_OP_ID <= `SLTIU;
                ROB_OP_ID <= `SLTIU;
            end
            else if(funct3 == `FUNCT3_XORI) begin
                RS_OP_ID <= `XORI;
                ROB_OP_ID <= `XORI;
            end
            else if(funct3 == `FUNCT3_ORI) begin
                RS_OP_ID <= `ORI;
                ROB_OP_ID <= `ORI;
            end
            else if(funct3 == `FUNCT3_ANDI) begin
                RS_OP_ID <= `ANDI;
                ROB_OP_ID <= `ANDI;
            end
            else if(funct3 == `FUNCT3_SLLI) begin
                RS_OP_ID <= `SLLI;
                ROB_OP_ID <= `SLLI;
            end
            else if(funct3 == `FUNCT3_SRLI) begin
                if(funct7 == `FUNCT7_SRLI) begin
                    RS_OP_ID <= `SRLI;
                    ROB_OP_ID <= `SRLI;
                end
                else if(funct7 == `FUNCT7_SRAI) begin
                    RS_OP_ID <= `SRAI;
                    ROB_OP_ID <= `SRAI;
                end
            end
        end
        else begin
            // LSB
            LSB_output_valid <= `False;
            // RF
            RF_rd_valid <= `False;
            RF_rs1_valid <= `False;
            RF_rs2_valid <= `False;
            // RS
            RS_output_valid <= `False;
            // ROB
            ROB_output_valid <= `False;
        end
*/