`include "/Users/weijie/Desktop/CPU2022/riscv/src/defines.v"
// 周期任务：进ALU_RS、拉进新RS、接受ROB更新
module RsvStation(
    input wire clk,
    input wire rst,
    input wire rdy,

    // InstQueue
    output reg IQ_RS_is_full,
    
    // Decoder
    input wire ID_input_valid,
    input wire [`DataWidth - 1 : 0] ID_inst_pc,
    input wire [`OpIdBus] ID_OP_ID,
    input wire [`RegIndexBus] ID_rd,
    input wire [`ImmWidth - 1 : 0] ID_imm,
    output reg ID_RS_is_full,
    
    // ReorderBuffer
    input wire [`ROBIDBus] ROB_new_ID,
    input wire ROB_input_valid,
    input wire [`RegIndexBus] ROB_update_ROB_id,
    input wire [`DataWidth - 1 : 0] ROB_value,

    // RegFile
    input wire RF_need_rd_flag,
    input wire RF_rd_valid,
    input wire [`ROBIDBus] RF_rd_ROB_id,
    input wire RF_need_rs1_flag,
    input wire RF_rs1_valid,
    input wire [`DataWidth - 1 : 0] RF_reg_rs1,
    input wire [`ROBIDBus] RF_rs1_ROB_id,
    input wire RF_need_rs2_flag,
    input wire RF_rs2_valid,
    input wire [`DataWidth - 1 : 0] RF_reg_rs2,
    input wire [`ROBIDBus] RF_rs2_ROB_id,

    // ALU_RS
    output reg ALU_output_valid,
    output reg [`OpIdBus] ALU_OP_ID,
    output reg [`DataWidth - 1 : 0] ALU_inst_pc,
    output reg [`DataWidth - 1 : 0] ALU_reg_rs1,
    output reg [`DataWidth - 1 : 0] ALU_reg_rs2,
    output reg [`ImmWidth - 1 : 0] ALU_imm,
    output reg [`ROBIDBus] ALU_ROB_id,

    // roll back
    input wire ROB_roll_back_flag

);

reg [4 : 0] siz;
reg [`RSSize - 1 : 0] occupied_judger;              // is this position valid ?
reg [`ROBIDBus] ROB_ids[`RSSize - 1 : 0];           // id of inst
reg [`AddrWidth - 1 : 0] inst_pcs[`RSSize - 1 : 0]; // pc of inst
reg [`OpIdBus] OP_IDs[`RSSize - 1 : 0];             // what is the op ?
reg [`RegIndexBus] rds[`RSSize - 1 : 0];            // rd
reg [`RSSize - 1 : 0] rs1_valid_judger;
reg [`RSSize - 1 : 0] rs2_valid_judger;             // `Fasle -> need ROB_id
reg [`DataWidth - 1 : 0] reg_rs1s[`RSSize - 1 : 0]; 
reg [`DataWidth - 1 : 0] reg_rs2s[`RSSize - 1 : 0];
reg [`ROBIDBus] id1s[`RSSize - 1 : 0];
reg [`ROBIDBus] id2s[`RSSize - 1 : 0];
reg [`ImmWidth - 1 : 0] imms[`RSSize - 1 : 0];
wire [`RSSize - 1 : 0] ready_judger;                // can the inst be sent to ALU ?
assign ready_judger[0] = ((rs1_valid_judger[0] == `True) && (rs2_valid_judger[0] == `True)) ? `True : `False;
assign ready_judger[1] = ((rs1_valid_judger[1] == `True) && (rs2_valid_judger[1] == `True)) ? `True : `False;
assign ready_judger[2] = ((rs1_valid_judger[2] == `True) && (rs2_valid_judger[2] == `True)) ? `True : `False;
assign ready_judger[3] = ((rs1_valid_judger[3] == `True) && (rs2_valid_judger[3] == `True)) ? `True : `False;
assign ready_judger[4] = ((rs1_valid_judger[4] == `True) && (rs2_valid_judger[4] == `True)) ? `True : `False;
assign ready_judger[5] = ((rs1_valid_judger[5] == `True) && (rs2_valid_judger[5] == `True)) ? `True : `False;
assign ready_judger[6] = ((rs1_valid_judger[6] == `True) && (rs2_valid_judger[6] == `True)) ? `True : `False;
assign ready_judger[7] = ((rs1_valid_judger[7] == `True) && (rs2_valid_judger[7] == `True)) ? `True : `False;
assign ready_judger[8] = ((rs1_valid_judger[8] == `True) && (rs2_valid_judger[8] == `True)) ? `True : `False;
assign ready_judger[9] = ((rs1_valid_judger[9] == `True) && (rs2_valid_judger[9] == `True)) ? `True : `False;
assign ready_judger[10] = ((rs1_valid_judger[10] == `True) && (rs2_valid_judger[10] == `True)) ? `True : `False;
assign ready_judger[11] = ((rs1_valid_judger[11] == `True) && (rs2_valid_judger[11] == `True)) ? `True : `False;
assign ready_judger[12] = ((rs1_valid_judger[12] == `True) && (rs2_valid_judger[12] == `True)) ? `True : `False;
assign ready_judger[13] = ((rs1_valid_judger[13] == `True) && (rs2_valid_judger[13] == `True)) ? `True : `False;
assign ready_judger[14] = ((rs1_valid_judger[14] == `True) && (rs2_valid_judger[14] == `True)) ? `True : `False;
assign ready_judger[15] = ((rs1_valid_judger[15] == `True) && (rs2_valid_judger[15] == `True)) ? `True : `False;

wire RS_is_full;
assign RS_is_full = (siz == 5'b10000 || (siz == 5'b01111 && RS_ind_to_ALU == 5'b10000)) ? `True : `False;
/*
assign RS_is_full = ((occupied_judger[0] == `True && ready_judger[0] == `False) 
                  && (occupied_judger[1] == `True && ready_judger[1] == `False)
                  && (occupied_judger[2] == `True && ready_judger[2] == `False)
                  && (occupied_judger[3] == `True && ready_judger[3] == `False)
                  && (occupied_judger[4] == `True && ready_judger[4] == `False)
                  && (occupied_judger[5] == `True && ready_judger[5] == `False)
                  && (occupied_judger[6] == `True && ready_judger[6] == `False)
                  && (occupied_judger[7] == `True && ready_judger[7] == `False)
                  && (occupied_judger[8] == `True && ready_judger[8] == `False)
                  && (occupied_judger[9] == `True && ready_judger[9] == `False)
                  && (occupied_judger[10] == `True && ready_judger[10] == `False)
                  && (occupied_judger[11] == `True && ready_judger[11] == `False)
                  && (occupied_judger[12] == `True && ready_judger[12] == `False)
                  && (occupied_judger[13] == `True && ready_judger[13] == `False)
                  && (occupied_judger[14] == `True && ready_judger[14] == `False)
                  && (occupied_judger[15] == `True && ready_judger[15] == `False)) ? `True : `False;
*/
// 弹出也弹出不了

wire [4 : 0] RS_ind_to_ALU; // RS to ALU_RS
assign RS_ind_to_ALU = (occupied_judger[0] == `True && ready_judger[0] == `True) ? 5'b00000 : 
                       (occupied_judger[1] == `True && ready_judger[1] == `True) ? 5'b00001 : 
                       (occupied_judger[2] == `True && ready_judger[2] == `True) ? 5'b00010 : 
                       (occupied_judger[3] == `True && ready_judger[3] == `True) ? 5'b00011 : 
                       (occupied_judger[4] == `True && ready_judger[4] == `True) ? 5'b00100 : 
                       (occupied_judger[5] == `True && ready_judger[5] == `True) ? 5'b00101 : 
                       (occupied_judger[6] == `True && ready_judger[6] == `True) ? 5'b00110 : 
                       (occupied_judger[7] == `True && ready_judger[7] == `True) ? 5'b00111 : 
                       (occupied_judger[8] == `True && ready_judger[8] == `True) ? 5'b01000 : 
                       (occupied_judger[9] == `True && ready_judger[9] == `True) ? 5'b01001 :             
                       (occupied_judger[10] == `True && ready_judger[10] == `True) ? 5'b01010 :
                       (occupied_judger[11] == `True && ready_judger[11] == `True) ? 5'b01011 : 
                       (occupied_judger[12] == `True && ready_judger[12] == `True) ? 5'b01100 : 
                       (occupied_judger[13] == `True && ready_judger[13] == `True) ? 5'b01101 : 
                       (occupied_judger[14] == `True && ready_judger[14] == `True) ? 5'b01110 : 
                       (occupied_judger[15] == `True && ready_judger[15] == `True) ? 5'b01111 : 5'b10000;

wire [`AddrWidth - 1 : 0] debug_inst_pc_to_ALU;
assign debug_inst_pc_to_ALU = inst_pcs[RS_ind_to_ALU[3 : 0]];
wire [`OpIdBus] debug_OP_ID_to_ALU;
assign debug_OP_ID_to_ALU = OP_IDs[RS_ind_to_ALU[3 : 0]];

wire [3 : 0] debug_ind_reg_rs1;
assign debug_ind_reg_rs1 = RS_ind_to_ALU[3 : 0];
wire [`DataWidth - 1 : 0] debug_reg_rs1;
assign debug_reg_rs1 = reg_rs1s[RS_ind_to_ALU[3 : 0]];
wire [`DataWidth - 1 : 0] debug_ROB_update_reg;
assign debug_ROB_update_reg = (ROB_input_valid != `True) ? {32{1'b0}} : 
                              (occupied_judger[RS_ind_to_ALU[3 : 0]] != `True) ? {{30{1'b0}}, 2'b01} : 
                              (rs1_valid_judger[RS_ind_to_ALU[3 : 0]] != `False || id1s[RS_ind_to_ALU[3 : 0]] != ROB_update_ROB_id) ? {{30{1'b0}}, 2'b10} : ROB_value;

wire [4 : 0] RS_ind_valid_pos; // RS from ID
assign RS_ind_valid_pos = (occupied_judger[0] == `False || ready_judger[0] == `True) ? 5'b00000 : 
                          (occupied_judger[1] == `False || ready_judger[1] == `True) ? 5'b00001 : 
                          (occupied_judger[2] == `False || ready_judger[2] == `True) ? 5'b00010 : 
                          (occupied_judger[3] == `False || ready_judger[3] == `True) ? 5'b00011 : 
                          (occupied_judger[4] == `False || ready_judger[4] == `True) ? 5'b00100 : 
                          (occupied_judger[5] == `False || ready_judger[5] == `True) ? 5'b00101 : 
                          (occupied_judger[6] == `False || ready_judger[6] == `True) ? 5'b00110 : 
                          (occupied_judger[7] == `False || ready_judger[7] == `True) ? 5'b00111 : 
                          (occupied_judger[8] == `False || ready_judger[8] == `True) ? 5'b01000 : 
                          (occupied_judger[9] == `False || ready_judger[9] == `True) ? 5'b01001 :             
                          (occupied_judger[10] == `False || ready_judger[10] == `True) ? 5'b01010 :
                          (occupied_judger[11] == `False || ready_judger[11] == `True) ? 5'b01011 : 
                          (occupied_judger[12] == `False || ready_judger[12] == `True) ? 5'b01100 : 
                          (occupied_judger[13] == `False || ready_judger[13] == `True) ? 5'b01101 : 
                          (occupied_judger[14] == `False || ready_judger[14] == `True) ? 5'b01110 : 
                          (occupied_judger[15] == `False || ready_judger[15] == `True) ? 5'b01111 : 5'b10000;

wire debug_from_ID_rs1_valid;
assign debug_from_ID_rs1_valid = rs1_valid_judger[1];
wire debug_from_ID_rs2_valid;
assign debug_from_ID_rs2_valid = rs2_valid_judger[1];
wire [`AddrWidth - 1 : 0] debug_from_ID_inst_pc;
assign debug_from_ID_inst_pc = inst_pcs[1];

always @(*) begin
    IQ_RS_is_full = RS_is_full;
    ID_RS_is_full = RS_is_full;
end

integer i;

always @(posedge clk) begin
    if(rst == `True) begin
        siz <= 5'b00000;
        for(i = 0; i < `RSSize; i = i + 1) begin
            occupied_judger[i] <= `False;
        end
        // ALU_RS
        ALU_output_valid <= `False;
    end
    else if(rdy == `False) begin
    end
    else if(ROB_roll_back_flag == `False) begin
        // ROB update RS
        if(ROB_input_valid == `True) begin
            for(i = 0; i < `RSSize; i = i + 1) begin
                if(occupied_judger[i] == `True) begin
                    if(rs1_valid_judger[i] == `False && id1s[i] == ROB_update_ROB_id) begin
                        rs1_valid_judger[i] <= `True;
                        reg_rs1s[i] <= ROB_value;
                    end
                    if(rs2_valid_judger[i] == `False && id2s[i] == ROB_update_ROB_id) begin
                        rs2_valid_judger[i] <= `True;
                        reg_rs2s[i] <= ROB_value;
                    end 
                end
            end
        end
        // update siz
        if(ID_input_valid == `True) begin
            if(RS_ind_to_ALU == 5'b10000) siz <= siz + 5'b00001;
            else siz <= siz;
        end
        else begin
            if(RS_ind_to_ALU == 5'b10000) siz <= siz;
            else siz <= siz - 5'b00001;
        end
        // to ALU
        if(RS_ind_to_ALU == 5'b10000) begin // 没有可以进入 ALU 的
            ALU_output_valid <= `False;
        end
        else begin
            // reg
            occupied_judger[RS_ind_to_ALU[3 : 0]] <= `False;
            rs1_valid_judger[RS_ind_to_ALU[3 : 0]] <= `False;
            rs2_valid_judger[RS_ind_to_ALU[3 : 0]] <= `False;
            // output
            ALU_output_valid <= `True;
            ALU_OP_ID <= OP_IDs[RS_ind_to_ALU[3 : 0]];
            ALU_inst_pc <= inst_pcs[RS_ind_to_ALU[3 : 0]];
            ALU_reg_rs1 <= reg_rs1s[RS_ind_to_ALU[3 : 0]];
            ALU_reg_rs2 <= reg_rs2s[RS_ind_to_ALU[3 : 0]];
            ALU_imm <= imms[RS_ind_to_ALU[3 : 0]];
            ALU_ROB_id <= ROB_ids[RS_ind_to_ALU[3 : 0]];
        end
        // from ID
        if(ID_input_valid == `True) begin
            // reg 
            occupied_judger[RS_ind_valid_pos[3 : 0]] <= `True;
            ROB_ids[RS_ind_valid_pos[3 : 0]] <= ROB_new_ID;
            inst_pcs[RS_ind_valid_pos[3 : 0]] <= ID_inst_pc;
            OP_IDs[RS_ind_valid_pos[3 : 0]] <= ID_OP_ID;
            rds[RS_ind_valid_pos[3 : 0]] <= ID_rd;
            if(RF_need_rs1_flag == `True) begin
                if(RF_rs1_valid == `True) begin
                    reg_rs1s[RS_ind_valid_pos[3 : 0]] <= RF_reg_rs1;
                    rs1_valid_judger[RS_ind_valid_pos[3 : 0]] <= `True;
                end
                else begin
                    rs1_valid_judger[RS_ind_valid_pos[3 : 0]] <= `False;
                    id1s[RS_ind_valid_pos[3 : 0]] <= RF_rs1_ROB_id;
                end
            end
            else begin
                rs1_valid_judger[RS_ind_valid_pos[3 : 0]] <= `True;
            end
            if(RF_need_rs2_flag == `True) begin
                if(RF_rs2_valid == `True) begin
                    reg_rs2s[RS_ind_valid_pos[3 : 0]] <= RF_reg_rs2;
                    rs2_valid_judger[RS_ind_valid_pos[3 : 0]] <= `True;
                end
                else begin
                    rs2_valid_judger[RS_ind_valid_pos[3 : 0]] <= `False;
                    id2s[RS_ind_valid_pos[3 : 0]] <= RF_rs2_ROB_id;
                end
            end
            else begin
                rs2_valid_judger[RS_ind_valid_pos[3 : 0]] <= `True;
            end
            imms[RS_ind_valid_pos[3 : 0]] <= ID_imm;
        end
    end
    else begin
        siz <= 5'b00000;
        for(i = 0; i < `RSSize; i = i + 1) begin
            occupied_judger[i] <= `False;
        end
        // ALU_RS
        ALU_output_valid <= `False;
    end
end

endmodule

/*
always @(posedge clk) begin
    if(rst == `True || ROB_roll_back_flag == `True) begin
        siz <= 5'b00000;
        for(i = 0; i < `RSSize; i = i + 1) begin
            occupied_judger[i] <= `False;
            ROB_ids[i] <= {4{1'b0}};
            inst_pcs[i] <= {32{1'b0}};
            OP_IDs[i] <= {6{1'b0}};
            rds[i] <= {5{1'b0}};
            rs1_valid_judger[i] <= `False;
            rs2_valid_judger[i] <= `False;
            reg_rs1s[i] <= {32{1'b0}};
            reg_rs2s[i] <= {32{1'b0}};
            id1s[i] <= {4{1'b0}};
            id2s[i] <= {4{1'b0}};
            imms[i] <= {32{1'b0}};
        end
        // ALU_RS
        ALU_output_valid <= `False;
    end
    else if(rdy == `False) begin
    end
    else if(RS_is_full == `True) begin 
        if(ROB_input_valid == `True) begin
            for(i = 0; i < `RSSize; i = i + 1) begin
                if(occupied_judger[i] == `True) begin
                    if(rs1_valid_judger[i] == `False && id1s[i] == ROB_update_ROB_id) begin
                        rs1_valid_judger[i] <= `True;
                        reg_rs1s[i] <= ROB_value;
                    end
                    if(rs2_valid_judger[i] == `False && id2s[i] == ROB_update_ROB_id) begin
                        rs2_valid_judger[i] <= `True;
                        reg_rs2s[i] <= ROB_value;
                    end 
                end
            end
        end
    end
    else begin
        if(ROB_input_valid == `True) begin
            for(i = 0; i < `RSSize; i = i + 1) begin
                if(occupied_judger[i] == `True) begin
                    if(rs1_valid_judger[i] == `False && id1s[i] == ROB_update_ROB_id) begin
                        rs1_valid_judger[i] <= `True;
                        reg_rs1s[i] <= ROB_value;
                    end
                    if(rs2_valid_judger[i] == `False && id2s[i] == ROB_update_ROB_id) begin
                        rs2_valid_judger[i] <= `True;
                        reg_rs2s[i] <= ROB_value;
                    end 
                end
            end
        end
        if(RS_ind_to_ALU == 5'b10000) begin // 没有可以进入 ALU 的
            ALU_output_valid <= `False;
        end
        else begin
            // reg
            occupied_judger[RS_ind_to_ALU[3 : 0]] <= `False;
            rs1_valid_judger[RS_ind_to_ALU[3 : 0]] <= `False;
            rs2_valid_judger[RS_ind_to_ALU[3 : 0]] <= `False;
            // output
            ALU_output_valid <= `True;
            ALU_OP_ID <= OP_IDs[RS_ind_to_ALU[3 : 0]];
            ALU_inst_pc <= inst_pcs[RS_ind_to_ALU[3 : 0]];
            ALU_reg_rs1 <= reg_rs1s[RS_ind_to_ALU[3 : 0]];
            ALU_reg_rs2 <= reg_rs2s[RS_ind_to_ALU[3 : 0]];
            ALU_imm <= imms[RS_ind_to_ALU[3 : 0]];
            ALU_ROB_id <= ROB_ids[RS_ind_to_ALU[3 : 0]];
        end
        if(RS_ind_valid_pos == 5'b10000) begin // 其实就是 full 
        end
        else if(ID_input_valid == `True) begin
            // reg 
            occupied_judger[RS_ind_valid_pos[3 : 0]] <= `True;
            ROB_ids[RS_ind_valid_pos[3 : 0]] <= ROB_new_ID;
            inst_pcs[RS_ind_valid_pos[3 : 0]] <= ID_inst_pc;
            OP_IDs[RS_ind_valid_pos[3 : 0]] <= ID_OP_ID;
            rds[RS_ind_valid_pos[3 : 0]] <= ID_rd;
            if(RF_need_rs1_flag == `True) begin
                if(RF_rs1_valid == `True) begin
                    reg_rs1s[RS_ind_valid_pos[3 : 0]] <= RF_reg_rs1;
                    rs1_valid_judger[RS_ind_valid_pos[3 : 0]] <= `True;
                end
                else begin
                    rs1_valid_judger[RS_ind_valid_pos[3 : 0]] <= `False;
                    id1s[RS_ind_valid_pos[3 : 0]] <= RF_rs1_ROB_id;
                end
            end
            else begin
                rs1_valid_judger[RS_ind_valid_pos[3 : 0]] <= `True;
            end
            if(RF_need_rs2_flag == `True) begin
                if(RF_rs2_valid == `True) begin
                    reg_rs2s[RS_ind_valid_pos[3 : 0]] <= RF_reg_rs2;
                    rs2_valid_judger[RS_ind_valid_pos[3 : 0]] <= `True;
                end
                else begin
                    rs2_valid_judger[RS_ind_valid_pos[3 : 0]] <= `False;
                    id2s[RS_ind_valid_pos[3 : 0]] <= RF_rs2_ROB_id;
                end
            end
            else begin
                rs2_valid_judger[RS_ind_valid_pos[3 : 0]] <= `True;
            end
            imms[RS_ind_valid_pos[3 : 0]] <= ID_imm;
        end
    end
end
*/