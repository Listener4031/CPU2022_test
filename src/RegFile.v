`include "/Users/weijie/Desktop/CPU2022/riscv/src/defines.v"

module RegFile(
    input wire clk,
    input wire rst,
    input wire rdy,

    // Decoder
    input wire ID_rd_valid,
    input wire [`RegIndexBus] ID_rd,
    input wire ID_rs1_valid,
    input wire [`RegIndexBus] ID_rs1,
    input wire ID_rs2_valid,
    input wire [`RegIndexBus] ID_rs2,

    // RsvStation
    output reg RS_need_rd_flag,
    output reg RS_rd_valid,                      
    output reg [`ROBIDBus] RS_rd_ROB_id,
    output reg RS_need_rs1_flag,
    output reg RS_rs1_valid,                    // `True -> get RS_reg_rs1 (value), `False -> get ROB_id
    output reg [`DataWidth - 1 : 0] RS_reg_rs1, 
    output reg [`ROBIDBus] RS_rs1_ROB_id,
    output reg RS_need_rs2_flag,
    output reg RS_rs2_valid,
    output reg [`DataWidth - 1 : 0] RS_reg_rs2,
    output reg [`ROBIDBus] RS_rs2_ROB_id,

    // LSBuffer
    output reg LSB_need_rd_flag,
    output reg LSB_rd_valid,
    output reg [`ROBIDBus] LSB_rd_ROB_id,
    output reg LSB_need_rs1_flag,
    output reg LSB_rs1_valid,
    output reg [`DataWidth - 1 : 0] LSB_reg_rs1,
    output reg [`ROBIDBus] LSB_rs1_ROB_id,
    output reg LSB_need_rs2_flag,
    output reg LSB_rs2_valid,
    output reg [`DataWidth - 1 : 0] LSB_reg_rs2,
    output reg [`ROBIDBus] LSB_rs2_ROB_id,

    // ReorderBuffer
    input wire [`ROBIDBus] ROB_rd_ROB_id,
    input wire ROB_input_valid,
    input wire [`RegIndexBus] ROB_rd,
    input wire [`DataWidth - 1 : 0] ROB_value,

    // roll back
    input wire ROB_roll_back_flag

);

reg [`DataWidth - 1 : 0] register[`RegSize - 1 : 0];
reg [`RegSize - 1 : 0] invalid_judger;                // `True -> need ROB_id
reg [`ROBIDBus] ROB_ids[`RegSize - 1 : 0];

always @(*) begin                              // RS from RF get ROB_id
    RS_need_rd_flag = ID_rd_valid;
    if(ID_rd_valid == `True) begin
        if(invalid_judger[ID_rd] == `True) begin
            RS_rd_valid = `False;
            RS_rd_ROB_id = ROB_ids[ID_rd];
        end
        else begin
            RS_rd_valid = `True;
        end
    end
    RS_need_rs1_flag = ID_rs1_valid;
    if(ID_rs1_valid == `True) begin
        if(invalid_judger[ID_rs1] == `True) begin
            RS_rs1_valid = `False;
            RS_rs1_ROB_id = ROB_ids[ID_rs1];
        end
        else begin
            RS_rs1_valid = `True;
            RS_reg_rs1 = register[ID_rs1];
        end
    end
    RS_need_rs2_flag = ID_rs2_valid;
    if(ID_rs2_valid == `True) begin
        if(invalid_judger[ID_rs2] == `True) begin
            RS_rs2_valid = `False;
            RS_rs2_ROB_id = ROB_ids[ID_rs2];
        end
        else begin
            RS_rs2_valid = `True;
            RS_reg_rs2 = register[ID_rs2];
        end
    end
end

always @(*) begin                              // LSB from RF get ROB_id
    LSB_need_rd_flag = ID_rd_valid;
    if(ID_rd_valid == `True) begin
        if(invalid_judger[ID_rd] == `True) begin
            LSB_rd_valid = `False;
            LSB_rd_ROB_id = ROB_ids[ID_rd];
        end
        else begin
            LSB_rd_valid = `True;
        end
    end
    LSB_need_rs1_flag = ID_rs1_valid;
    if(ID_rs1_valid == `True) begin
        if(invalid_judger[ID_rs1] == `True) begin
            LSB_rs1_valid = `False;
            LSB_rs1_ROB_id = ROB_ids[ID_rs1];
        end
        else begin
            LSB_rs1_valid = `True;
            LSB_reg_rs1 = register[ID_rs1];
        end
    end
    LSB_need_rs2_flag = ID_rs2_valid;
    if(ID_rs2_valid == `True) begin
        if(invalid_judger[ID_rs2] == `True) begin
            LSB_rs2_valid = `False;
            LSB_rs2_ROB_id = ROB_ids[ID_rs2];
        end
        else begin
            LSB_rs2_valid = `True;
            LSB_reg_rs2 = register[ID_rs2];
        end
    end
end

integer i;

always @(*) begin
    if(ROB_input_valid == `True) begin
        register[ROB_rd] = (ROB_rd == 5'b00000) ? {32{1'b0}} : ROB_value;
        invalid_judger[ROB_rd] = `False;
    end
end

always @(posedge clk) begin
    if(rst == `True) begin
        for(i = 0; i < `RegSize; i = i + 1) begin
            register[i] <= {32{1'b0}};
            invalid_judger[i] <= `False;
        end
    end
    else if(rdy == `False) begin
    end
    else if(ROB_roll_back_flag == `False) begin
        if(ID_rd_valid == `True) begin
            invalid_judger[ID_rd] <= `True;
            ROB_ids[ID_rd] <= ROB_rd_ROB_id;
        end
        /*
        if(ROB_input_valid == `True) begin
            if(ROB_rd != 5'b00000) register[ROB_rd] <= ROB_value;
            invalid_judger[ROB_rd] <= `False;
        end
        */
    end
    else begin
        for(i = 0; i < `RegSize; i = i + 1) begin
            invalid_judger[i] <= `False;
        end
    end
end

endmodule