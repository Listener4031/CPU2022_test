`include "/Users/weijie/Desktop/CPU2022/riscv/src/defines.v"

module InstFetcher(
    input wire clk,
    input wire rst,
    input wire rdy,

    // MemControllor
    input wire MC_input_valid,
    input wire [`InstWidth - 1 : 0] MC_inst,
    output reg MC_need_fetch,                    // miss -> `True -> MC_fetch
    output reg [`AddrWidth - 1 : 0] MC_fetch_pc,

    // Predictor
    input wire PDC_need_jump,
    input wire [`AddrWidth - 1 : 0] PDC_predicted_imm,
    output reg [`InstWidth - 1 : 0] PDC_inst,
    output reg [`AddrWidth - 1 : 0] PDC_inst_pc,

    // InstQueue
    input wire IQ_is_full,                          // `False -> 尝试 fetch
    output reg IQ_output_valid,
    output reg [`InstWidth - 1 : 0] IQ_inst,
    output reg [`AddrWidth - 1 : 0] IQ_inst_pc,
    output reg IQ_predicted_to_jump,
    output reg [`AddrWidth - 1 : 0] IQ_predicted_pc,

    // roll back
    input wire ROB_roll_back_flag,
    input wire [`AddrWidth - 1 : 0] ROB_roll_back_pc
    
);

reg [`ICacheSize - 1 : 0] occupied_judger;
reg [`TagWidth - 1 : 0] tags[`ICacheSize - 1 : 0];   // 31 : 10 -> 21 : 0
reg [`InstWidth - 1 : 0] insts[`ICacheSize - 1 : 0];

reg [`AddrWidth - 1 : 0] fetch_pc;

reg status; // 1'b0 -> IDLE, 1'b1 -> fetch

wire hit;
assign hit = (occupied_judger[fetch_pc[`ICacheIndex]] == `True && tags[fetch_pc[`ICacheIndex]] == fetch_pc[31 : 10]) ? `True : `False;

always @(*) begin
    PDC_inst = (hit == `True) ? insts[fetch_pc[`ICacheIndex]] : MC_inst;
    PDC_inst_pc = fetch_pc;
end

integer i;

always @(posedge clk) begin
    if(rst == `True) begin
        for(i = 0; i < `ICacheSize; i = i + 1) begin
            occupied_judger[i] <= `False;
            tags[i] <= {22{1'b0}};
            insts[i] <= {32{1'b0}};
        end
        fetch_pc <= 32'h0;
        status <= 1'b0;
        // MC
        MC_need_fetch <= `False;
        // IQ
        IQ_output_valid <= `False;
    end
    else if(rdy == `False) begin
    end
    else if(ROB_roll_back_flag == `False) begin
        if(IQ_is_full == `True) begin // not fetch
            // MC
            MC_need_fetch <= `False;
            // IQ
            IQ_output_valid <= `False;
        end
        else begin                    // 如果不在拿，尝试去拿
            if(status == 1'b0) begin  // 正闲置
                if(hit == `True) begin
                    fetch_pc <= (PDC_need_jump == `True) ? (fetch_pc + PDC_predicted_imm) : (fetch_pc + 32'h4);
                    // MC
                    MC_need_fetch <= `False;
                    // IQ
                    IQ_output_valid <= `True;
                    IQ_inst <= insts[fetch_pc[`ICacheIndex]];
                    IQ_inst_pc <= fetch_pc;
                    IQ_predicted_to_jump <= PDC_need_jump;
                    IQ_predicted_pc <= (PDC_need_jump == `True) ? (fetch_pc + PDC_predicted_imm) : (fetch_pc + 32'h4);
                end
                else begin
                    status <= 1'b1;
                    // MC
                    MC_need_fetch <= `True;
                    MC_fetch_pc <= fetch_pc;
                    // IQ
                    IQ_output_valid <= `False;
                end
            end
            else begin // 1'b1 正在等 MC 拿指令, check if MC_inst is ok
                if(MC_input_valid == `True) begin
                    occupied_judger[fetch_pc[`ICacheIndex]] <= `True;
                    tags[fetch_pc[`ICacheIndex]] <= fetch_pc[31 : 10];
                    insts[fetch_pc[`ICacheIndex]] <= MC_inst;
                    fetch_pc <= (PDC_need_jump == `True) ? (fetch_pc + PDC_predicted_imm) : (fetch_pc + 32'h4);
                    status <= 1'b0;
                    // MC
                    MC_need_fetch <= `False;
                    // IQ
                    IQ_output_valid <= `True;
                    IQ_inst <= MC_inst;
                    IQ_inst_pc <= fetch_pc;
                    IQ_predicted_to_jump <= PDC_need_jump;
                    IQ_predicted_pc <= (PDC_need_jump == `True) ? (fetch_pc + PDC_predicted_imm) : (fetch_pc + 32'h4);
                end
                else begin
                    // MC
                    MC_need_fetch <= `False;
                    // IQ
                    IQ_output_valid <= `False;
                end 
            end
        end
    end
    else begin // roll back
        fetch_pc <= ROB_roll_back_pc;
        status <= 1'b0;
        // MC
        MC_need_fetch <= `False;
        // IQ
        IQ_output_valid <= `False;
    end
end

endmodule