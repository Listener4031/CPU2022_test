`include "/Users/weijie/Desktop/CPU2022/riscv/src/defines.v"
// 接受 Decoder 进队尾, 队头检查出队, 接受更新 
module ReorderBuffer(
    input wire clk,
    input wire rst,
    input wire rdy,

    // InstQueue
    output reg IQ_ROB_is_full,

    // Decoder
    input wire ID_input_valid,           // `True -> 队尾申请
    input wire [`AddrWidth - 1 : 0] ID_inst_pc,
    input wire [`OpIdBus] ID_OP_ID,
    input wire [`RegIndexBus] ID_rd,
    input wire ID_predicted_to_jump,
    input wire [`AddrWidth - 1 : 0] ID_predicted_pc,
    output reg ID_ROB_is_full,
    
    // RsvStation
    output reg [`ROBIndexBus] RS_ROB_id,         // new ROB_id for a new RS(当前的)
    output reg RS_output_valid,
    output reg [`RegIndexBus] RS_update_ROB_id,
    output reg [`DataWidth - 1 : 0] RS_value,

    // LSBuffer
    output reg [`ROBIndexBus] LSB_ROB_id,         // new ROB_id for a new LS(当前的)
    output reg LSB_output_valid,
    output reg [`RegIndexBus] LSB_update_ROB_id,
    output reg [`DataWidth - 1 : 0] LSB_value,
    output reg LSB_head_store_to_launch,
    output reg [`ROBIndexBus] LSB_head_ROB_id,

    // ALU_RS
    input wire ALU_RS_input_valid,
    input wire [`ROBIDBus] ALU_RS_ROB_id,
    input wire [`DataWidth - 1 : 0] ALU_RS_value,
    input wire [`AddrWidth - 1 : 0] ALU_RS_targeted_pc,
    input wire ALU_RS_jump_flag,                        // 当前指令是不是要跳转

    // ALU_LS
    input wire ALU_LS_input_valid,
    input wire [`ROBIDBus] ALU_LS_ROB_id,
    input wire [`DataWidth - 1 : 0] ALU_LS_value,
    input wire [`AddrWidth - 1 : 0] ALU_LS_addr,

    // RegFile
    output reg [`ROBIndexBus] RF_ROB_id,         // 当前的
    output reg RF_output_valid,
    output reg [`RegIndexBus] RF_rd,
    output reg [`DataWidth - 1 : 0] RF_value,

    // MemControllor
    output reg MC_output_valid,
    output reg [`OpIdBus] MC_OP_ID,
    output reg [`DataWidth - 1 : 0] MC_value,
    output reg [`AddrWidth - 1 : 0] MC_addr,

    // Predictor
    output reg PDC_output_valid,
    output reg PDC_hit,
    output reg [`AddrWidth - 1 : 0] PDC_inst_pc,

    // roll back
    // ALU_LS
    output reg ALU_LS_roll_back_flag,
    // ALU_RS
    output reg ALU_RS_roll_back_flag,
    // Decoder
    output reg ID_roll_back_flag,
    // InstFetcher
    output reg IF_roll_back_flag,
    output reg [`AddrWidth - 1 : 0] IF_roll_back_pc,
    // InstQueue
    output reg IQ_roll_back_flag,
    // LSBuffer
    output reg LSB_roll_back_flag,
    // MemControllor
    output reg MC_roll_back_flag,
    // RegFile
    output reg RF_roll_back_flag,
    // RsvStation
    output reg RS_roll_back_flag

);

reg [4 : 0] siz; 
reg [`ROBIndexBus] head; // 指向第一个
reg [`ROBIndexBus] tail; // 指向最后一个
// queue index -> ROB_id
reg [`ROBSize - 1 : 0] ready_judger;     // head is `True -> update
reg [`OpIdBus] OP_IDs[`ROBSize - 1 : 0];
reg [`DataWidth - 1 : 0] inst_pcs[`ROBSize - 1 : 0];
reg [`RegIndexBus] rds[`ROBSize - 1 : 0];
reg [`DataWidth - 1 : 0] values[`ROBSize - 1 : 0];
reg [`AddrWidth - 1 : 0] addrs[`ROBSize - 1 : 0]; // ls
reg [`AddrWidth - 1 : 0] predicted_pcs[`ROBSize - 1 : 0]; // jal, jalr, br
reg [`AddrWidth - 1 : 0] targeted_pcs[`ROBSize -1 : 0];

reg [1 : 0] roll_back_flag;
reg [`AddrWidth - 1 : 0] roll_back_pc;

wire ROB_is_full;
assign ROB_is_full = (siz == 5'b10000 || (siz == 5'b01111 && ready_judger[head] == `False)) ? `True : `False;
//assign ROB_is_full = (siz == 5'b10000 && ready_judger[head] == `False) ? `True : `False;

wire ROB_full_warning;
assign ROB_full_warning = (siz == 5'b01111 && ready_judger[head] == `False) ? `True : `False;

wire [`ROBIndexBus] in_queue_pos;
assign in_queue_pos = (tail == 4'b1111) ? 4'b0000 : (tail + 4'b0001);

wire debug_launch;
assign debug_launch = (siz != 5'b00000 && ready_judger[head] == `True) ? `True : `False;
wire [`OpIdBus] debug_launch_OP_ID;
assign debug_launch_OP_ID = OP_IDs[head];
wire [`AddrWidth - 1 : 0] debug_launch_inst_pc;
assign debug_launch_inst_pc = inst_pcs[head];

wire OP_ID_differentiator0;
assign OP_ID_differentiator0 = (OP_IDs[head] == `NOP) ? `True : `False;
wire OP_ID_differentiator1;
assign OP_ID_differentiator1 = (OP_IDs[head] == `LUI 
                             || OP_IDs[head] == `AUIPC) ? `True : `False;
wire OP_ID_differentiator2;
assign OP_ID_differentiator2 = (OP_IDs[head] == `JAL 
                             || OP_IDs[head] == `JALR) ? `True : `False;
wire OP_ID_differentiator3;
assign OP_ID_differentiator3 = (OP_IDs[head] == `BEQ 
                             || OP_IDs[head] == `BNE 
                             || OP_IDs[head] == `BLT 
                             || OP_IDs[head] == `BGE 
                             || OP_IDs[head] == `BLTU 
                             || OP_IDs[head] == `BGEU) ? `True : `False;
wire OP_ID_differentiator4;
assign OP_ID_differentiator4 = (OP_IDs[head] == `LB 
                             || OP_IDs[head] == `LH 
                             || OP_IDs[head] == `LW 
                             || OP_IDs[head] == `LBU 
                             || OP_IDs[head] == `LHU) ? `True : `False;
wire OP_ID_differentiator5;
assign OP_ID_differentiator5 = (OP_IDs[head] == `SB 
                             || OP_IDs[head] == `SH 
                             || OP_IDs[head] == `SW) ? `True : `False;
wire OP_ID_differentiator6;
assign OP_ID_differentiator6 = (OP_IDs[head] == `ADD 
                             || OP_IDs[head] == `SUB 
                             || OP_IDs[head] == `SLL 
                             || OP_IDs[head] == `SLT 
                             || OP_IDs[head] == `SLTU 
                             || OP_IDs[head] == `XOR 
                             || OP_IDs[head] == `SRL 
                             || OP_IDs[head] == `SRA 
                             || OP_IDs[head] == `OR 
                             || OP_IDs[head] == `AND) ? `True : `False;
wire OP_ID_differentiator7;
assign OP_ID_differentiator7 = (OP_IDs[head] == `ADDI 
                             || OP_IDs[head] == `SLTI 
                             || OP_IDs[head] == `SLTIU 
                             || OP_IDs[head] == `XORI 
                             || OP_IDs[head] == `ORI 
                             || OP_IDs[head] == `ANDI 
                             || OP_IDs[head] == `SLLI 
                             || OP_IDs[head] == `SRLI 
                             || OP_IDs[head] == `SRAI) ? `True : `False;

wire is_branch;
assign is_branch = (OP_IDs[head] == `JAL || OP_IDs[head] == `JALR || OP_IDs[head] == `BEQ || OP_IDs[head] == `BNE
                  || OP_IDs[head] == `BLT || OP_IDs[head] == `BGE || OP_IDs[head] == `BLTU || OP_IDs[head] == `BGEU) ? `True : `False;

always @(*) begin
    IQ_ROB_is_full = ROB_is_full;
    ID_ROB_is_full = ROB_is_full;
    LSB_head_store_to_launch = (siz != 5'b00000 && ready_judger[head] == `True && OP_ID_differentiator5 == `True) ? `True : `False;
    LSB_head_ROB_id = head;
end

integer i;

always @(posedge clk) begin
    if(rst == `True) begin
        roll_back_flag <= 2'b00;
        siz <= 5'b00000;
        head <= 4'b0000;
        tail <= 4'b1111;
        for(i = 0; i < `ROBSize; i = i + 1) begin
            ready_judger[i] <= `False;
        end
        // RS
        RS_output_valid <= `False;
        // LSB
        LSB_output_valid <= `False;
        // RF
        RF_output_valid <= `False;
        // MC
        MC_output_valid <= `False;
        // PDC
        PDC_output_valid <= `False;
        // not roll back
        ALU_LS_roll_back_flag <= `False;
        ALU_RS_roll_back_flag <= `False;
        ID_roll_back_flag <= `False;
        IF_roll_back_flag <= `False;
        IQ_roll_back_flag <= `False;
        LSB_roll_back_flag <= `False;
        MC_roll_back_flag <= `False;
        RF_roll_back_flag <= `False;
        RS_roll_back_flag <= `False;
    end
    else if(rdy == `False) begin
    end
    else if(roll_back_flag == 2'b00) begin
        // roll_back_flag
        if(siz != 5'b00000 && ready_judger[head] == `True) begin
            if(OP_IDs[head] == `JAL) roll_back_flag <= 2'b00;
            else if(OP_IDs[head] == `JALR) roll_back_flag <= 2'b01;
            else if(OP_IDs[head] == `BEQ || OP_IDs[head] == `BNE || OP_IDs[head] == `BLT || OP_IDs[head] == `BGE || OP_IDs[head] == `BLTU || OP_IDs[head] == `BGEU) begin
                if(targeted_pcs[head] == predicted_pcs[head]) roll_back_flag <= 2'b00;
                else roll_back_flag <= 2'b01;
            end
            else roll_back_flag <= 2'b00;
        end
        else roll_back_flag <= 2'b00;
        roll_back_pc <= targeted_pcs[head];
        // not roll back
        ALU_LS_roll_back_flag <= `False;
        ALU_RS_roll_back_flag <= `False;
        ID_roll_back_flag <= `False;
        IF_roll_back_flag <= `False;
        IQ_roll_back_flag <= `False;
        LSB_roll_back_flag <= `False;
        MC_roll_back_flag <= `False;
        RF_roll_back_flag <= `False;
        RS_roll_back_flag <= `False;
        // update siz
        if(ID_input_valid == `True) begin
            if(siz != 5'b00000 && ready_judger[head] == `True) siz <= siz;
            else siz <= siz + 5'b00001;
        end
        else begin
            if(siz != 5'b00000 && ready_judger[head] == `True) siz <= siz - 5'b00001;
            else siz <= siz;
        end
        if(ID_input_valid == `True) begin
            ready_judger[in_queue_pos] <= `False;
            OP_IDs[in_queue_pos] <= ID_OP_ID;
            inst_pcs[in_queue_pos] <= ID_inst_pc;
            rds[in_queue_pos] <= ID_rd;
            if(ID_predicted_to_jump == `True) predicted_pcs[in_queue_pos] <= ID_predicted_pc;
            else predicted_pcs[in_queue_pos] <= ID_inst_pc + 32'h4;
            tail <= in_queue_pos;
        end
        if(siz != 5'b00000 && ready_judger[head] == `True) begin // 发射队首指令
            head <= (head == 4'b1111) ? 4'b0000 : (head + 4'b0001);
            if(OP_ID_differentiator1 == `True 
            || OP_ID_differentiator2 == `True 
            || OP_ID_differentiator4 == `True 
            || OP_ID_differentiator6 == `True 
            || OP_ID_differentiator7 == `True) begin
                // RS
                RS_output_valid <= `True;
                RS_update_ROB_id <= head;
                RS_value <= values[head];
                // LSB
                LSB_output_valid <= `True;
                LSB_update_ROB_id <= head;
                LSB_value <= values[head];
                // RF
                RF_output_valid <= `True;
                RF_rd <= rds[head];
                RF_value <= values[head];
                // MC
                MC_output_valid <= `False;
            end
            else if(OP_ID_differentiator5 == `True) begin // store
                // RS
                RS_output_valid <= `False;
                // LSB
                LSB_output_valid <= `False;
                // RF
                RF_output_valid <= `False;
                // MC
                MC_output_valid <= `True;
                MC_OP_ID <= OP_IDs[head];
                MC_value <= values[head];
                MC_addr <= addrs[head];
            end
            else begin // B
                // RS
                RS_output_valid <= `False;
                // LSB
                LSB_output_valid <= `False;
                // RF
                RF_output_valid <= `False;
                // MC
                MC_output_valid <= `False;
            end
            if(is_branch == `True) begin
                PDC_output_valid <= `True;
                PDC_inst_pc <= inst_pcs[head];
                PDC_hit <= (inst_pcs[head] + 32'h4 == targeted_pcs[head]) ? `False : `True;
            end
            else begin
                PDC_output_valid <= `False;
            end
            // debug
            if(inst_pcs[head] == 32'h10a4 || inst_pcs[head] == 32'h11dc || inst_pcs[head] == 32'h120c || inst_pcs[head] == 32'h1238) begin
                //$display(" ");
                //$display("inst_pc is %h", inst_pcs[head]);
                //$display("value is %b", values[head][7 : 0]);
                //$display("addr is %h", addrs[head]);
            end
        end
        else begin
            RS_output_valid <= `False;
            LSB_output_valid <= `False;
            RF_output_valid <= `False;
            MC_output_valid <= `False;
            PDC_output_valid <= `False;
        end
        if(ALU_RS_input_valid == `True) begin
            ready_judger[ALU_RS_ROB_id] <= `True;
            values[ALU_RS_ROB_id] <= ALU_RS_value;
            targeted_pcs[ALU_RS_ROB_id] <= (ALU_RS_jump_flag == `True) ? ALU_RS_targeted_pc : (inst_pcs[ALU_RS_ROB_id] + 32'h4);
        end
        if(ALU_LS_input_valid == `True) begin
            ready_judger[ALU_LS_ROB_id] <= `True;
            values[ALU_LS_ROB_id] <= ALU_LS_value;
            addrs[ALU_LS_ROB_id] <= ALU_LS_addr;
        end
    end
    else if(roll_back_flag == 2'b01) begin // roll back, modify pc
        roll_back_flag <= 2'b10;
        // ALU_LS
        ALU_LS_roll_back_flag <= `True;
        // ALU_RS
        ALU_RS_roll_back_flag <= `True;
        // ID
        ID_roll_back_flag <= `True;
        // IF
        IF_roll_back_flag <= `True;
        IF_roll_back_pc <= roll_back_pc;
        // IQ
        IQ_roll_back_flag <= `True;
        // LSB
        LSB_roll_back_flag <= `True;
        // MC
        MC_roll_back_flag <= `True;
        // RF
        RF_roll_back_flag <= `True;
        // RS
        RS_roll_back_flag <= `True;
        // debug
        //$display("roll back");
    end
    else begin
        roll_back_flag <= 2'b00;
        siz <= 5'b00000;
        head <= 4'b0000;
        tail <= 4'b1111;
        for(i = 0; i < `ROBSize; i = i + 1) begin
            ready_judger[i] <= `False;
        end
        // not roll back
        ALU_LS_roll_back_flag <= `False;
        ALU_RS_roll_back_flag <= `False;
        ID_roll_back_flag <= `False;
        IF_roll_back_flag <= `False;
        IQ_roll_back_flag <= `False;
        LSB_roll_back_flag <= `False;
        MC_roll_back_flag <= `False;
        RF_roll_back_flag <= `False;
        RS_roll_back_flag <= `False;
    end
end

always @(*) begin
    RS_ROB_id = in_queue_pos;
    LSB_ROB_id = in_queue_pos;
    RF_ROB_id = in_queue_pos;
end

endmodule