`include "/Users/weijie/Desktop/CPU2022/riscv/src/defines.v"

module InstQueue(
    input wire clk,
    input wire rst,
    input wire rdy,

    // ReorderBuffer
    input wire ROB_is_full,

    // RsvStation
    input wire RS_is_full,

    // LSBuffer
    input wire LSB_is_full,

    // InstFetcher
    output reg IF_IQ_is_full,                        

    // InstFetcher
    input wire IF_input_valid,
    input wire [`InstWidth - 1 : 0] IF_inst,
    input wire [`AddrWidth - 1 : 0] IF_inst_pc,
    input wire IF_predicted_to_jump,
    input wire [`AddrWidth - 1 : 0] IF_predicted_pc,

    // Decoder
    input wire ID_ready,
    output reg ID_output_valid,
    output reg [`InstWidth - 1 : 0] ID_inst,
    output reg [`AddrWidth - 1 : 0] ID_inst_pc,
    output reg ID_predicted_to_jump,
    output reg [`AddrWidth - 1 : 0] ID_predicted_pc,

    // roll back
    input wire ROB_roll_back_flag

);

wire [`OpcodeBus] opcode;
assign opcode = insts[head][6 : 0];

wire is_LSB;
assign is_LSB = (opcode == `OPCODE_L || opcode == `OPCODE_S) ? `True : `False;

wire not_launch_inst;
assign not_launch_inst = (siz == 5'b00000 || ID_ready == `False || ROB_is_full == `True || (is_LSB == `False && RS_is_full == `True) || (is_LSB == `True && LSB_is_full == `True)) ? `True : `False;

reg [4 : 0] siz;
reg [`IQIndexBus] head;
reg [`IQIndexBus] tail;
reg [`InstWidth - 1 : 0] insts[`IQSize - 1 : 0];
reg [`AddrWidth - 1 : 0] inst_pcs[`IQSize - 1 : 0];
reg [`IQSize - 1 : 0] predicted_jump_judger;
reg [`AddrWidth - 1 : 0] predicted_pcs[`IQSize - 1 : 0];

wire [`IQIndexBus] in_queue_pos;
assign in_queue_pos = (tail == 4'b1111) ? 4'b0000 : (tail + 4'b0001);

wire IQ_is_full;
assign IQ_is_full = (siz == 5'b10000 || (siz == 5'b01111 && not_launch_inst == `True));

always @(*) begin
    IF_IQ_is_full = IQ_is_full;
end

always @(posedge clk) begin
    if(rst == `True) begin
        siz <= 5'b00000;
        head <= 4'b0000;
        tail <= 4'b1111;
        // ID
        ID_output_valid <= `False;
    end
    else if(rdy == `False) begin
    end
    else if(ROB_roll_back_flag == `False) begin
        // update siz
        if(not_launch_inst == `True) begin
            if(IF_input_valid == `True) siz <= siz + 5'b00001;
            else siz <= siz;
        end
        else begin
            if(IF_input_valid == `True) siz <= siz;
            else siz <= siz - 5'b00001;
        end
        // check if launch
        if(not_launch_inst == `False) begin
            ID_output_valid <= `True;
            ID_inst <= insts[head];
            ID_inst_pc <= inst_pcs[head];
            ID_predicted_to_jump <= predicted_jump_judger[head];
            ID_predicted_pc <= predicted_pcs[head];
            head <= (head == 4'b1111) ? 4'b0000 : (head + 4'b0001);
        end
        else begin
            ID_output_valid <= `False;
        end
        // check if inqueue
        if(IF_input_valid == `True) begin
            insts[in_queue_pos] <= IF_inst;
            inst_pcs[in_queue_pos] <= IF_inst_pc;
            predicted_jump_judger[in_queue_pos] <= IF_predicted_to_jump;
            predicted_pcs[in_queue_pos] <= IF_predicted_pc;
            tail <= in_queue_pos;
        end
    end
    else begin
        siz <= 5'b00000;
        head <= 4'b0000;
        tail <= 4'b1111;
        // ID
        ID_output_valid <= `False;
    end
end

endmodule
