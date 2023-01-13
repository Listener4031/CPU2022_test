`include "/Users/weijie/Desktop/CPU2022/riscv/src/defines.v"

module Predictor(
    input wire clk,
    input wire rst,
    input wire rdy,

    // InstFetcher
    input wire [`InstWidth - 1 : 0] IF_inst,
    input wire [`AddrWidth - 1 : 0] IF_inst_pc,
    output reg IF_need_jump,
    output reg [`AddrWidth - 1 : 0] IF_predicted_imm,

    // ReorderBuffer
    input wire ROB_input_valid,
    input wire ROB_hit,
    input wire [`AddrWidth - 1 : 0] ROB_pc

);

reg [1 : 0] pdc[`PDCSize - 1 : 0];

always @(*) begin
    if(IF_inst[`OpcodeBus] == `OPCODE_JAL) begin
        IF_need_jump = `True;
        IF_predicted_imm = {{12{IF_inst[31]}}, IF_inst[19 : 12], IF_inst[20], IF_inst[30 : 21], 1'b0};
    end
    else if(IF_inst[`OpcodeBus] == `OPCODE_B) begin
        IF_need_jump = pdc[IF_inst_pc[9 : 2]][1];
        IF_predicted_imm = {{20{IF_inst[31]}}, IF_inst[7], IF_inst[30 : 25], IF_inst[11 : 8], 1'b0};
    end
    else begin
        IF_need_jump = `False;
        IF_predicted_imm = {{12{IF_inst[31]}}, IF_inst[19 : 12], IF_inst[20], IF_inst[30 : 21], 1'b0};
    end
end

integer i;

always @(posedge clk) begin
    if(rst == `True) begin
        for(i = 0; i < `PDCSize; i = i + 1) begin
            pdc[i] <= 2'b01;
        end
    end
    else if(rdy == `False) begin
    end
    else if(ROB_input_valid == `True) begin
        if(pdc[ROB_pc[9 : 2]] == 2'b00) begin
            pdc[ROB_pc[9 : 2]] <= (ROB_hit == `True) ? 2'b01 : 2'b00;
        end
        else if(pdc[ROB_pc[9 : 2]] == 2'b01) begin
            pdc[ROB_pc[9 : 2]] <= (ROB_hit == `True) ? 2'b10 : 2'b00;
        end
        else if(pdc[ROB_pc[9 : 2]] == 2'b10) begin
            pdc[ROB_pc[9 : 2]] <= (ROB_hit == `True) ? 2'b11 : 2'b01;
        end
        else begin // 2'b11
            pdc[ROB_pc[9 : 2]] <= (ROB_hit == `True) ? 2'b11 : 2'b10;
        end
    end
    else begin
    end
end

endmodule