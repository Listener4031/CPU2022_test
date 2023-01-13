`include "/Users/weijie/Desktop/CPU2022/riscv/src/defines.v"

module ALU_LS(
    input wire clk,
    input wire rst,
    input wire rdy,

    // LSBuffer
    input wire LSB_input_valid,
    input wire [`OpIdBus] LSB_OP_ID,
    input wire [`DataWidth - 1 : 0] LSB_inst_pc,
    input wire [`DataWidth - 1 : 0] LSB_reg_rs1,
    input wire [`DataWidth - 1 : 0] LSB_reg_rs2,
    input wire [`ImmWidth - 1 : 0] LSB_imm,
    input wire [`ROBIDBus] LSB_ROB_id,
    output reg LSB_enable,                        // `False -> next cycle LSB_input_valid == `False

    // ReorderBuffer
    output reg ROB_ouptut_valid,
    output reg [`ROBIDBus] ROB_ROB_id,
    output reg [`DataWidth - 1 : 0] ROB_value,
    output reg [`AddrWidth - 1 : 0] ROB_addr,

    // MemControllor
    input wire MC_MSB_is_full,                   // store
    input wire MC_finish_load,                   // load
    input wire [`DataWidth - 1 : 0] MC_value,
    output reg MC_need_load,
    output reg [`OpIdBus] MC_OP_ID,
    output reg [`AddrWidth - 1 : 0] MC_load_addr,

    // roll back
    input wire ROB_roll_back_flag

);

wire is_store;
assign is_store = (LSB_OP_ID == `SB || LSB_OP_ID == `SH || LSB_OP_ID == `SW) ? `True : `False;

reg [1 : 0] status;            // 00 -> ready, 01 -> load, 10 -> store, 11 -> none
reg [`AddrWidth - 1 : 0] addr;
reg [`DataWidth - 1 : 0] value;
reg [`OpIdBus] OP_ID;
reg [`ROBIDBus] ROB_id;

always @(*) begin
    LSB_enable = (status == 2'b00 && LSB_input_valid == `False) ? `True : `False;
end

always @(posedge clk) begin
    if(rst == `True) begin
        status <= 2'b00;
        addr <= {32{1'b0}};
        value <= {32{1'b0}};
        OP_ID <= {6{1'b0}};
        ROB_id <= {4{1'b0}};
        // ROB
        ROB_ouptut_valid <=`False;
        // MC
        MC_need_load <= `False;
    end
    else if(rdy == `False) begin
    end
    else if(ROB_roll_back_flag == `False) begin
        if(LSB_input_valid == `True && status != 2'b00) begin
            $display("eee");
        end
        if(LSB_input_valid == `True) begin         // status must be 2'b00
            if(is_store == `True) begin // store
                if(MC_MSB_is_full == `True) begin // 病态操作，从根本上防止发射
                    status <= 2'b10;
                    addr <= LSB_reg_rs1 + LSB_imm;
                    value <= LSB_reg_rs2;
                    OP_ID <= LSB_OP_ID;
                    ROB_id <= LSB_ROB_id;
                    // ROB
                    ROB_ouptut_valid <= `False;
                    // MC
                    MC_need_load <= `False;
                end
                else begin
                    status <= 2'b00;
                    // ROB
                    ROB_ouptut_valid <= `True;
                    ROB_ROB_id <= LSB_ROB_id;
                    ROB_value <= LSB_reg_rs2;
                    ROB_addr <= LSB_reg_rs1 + LSB_imm;
                    // MC
                    MC_need_load <= `False;
                end
            end
            else begin // load
                status <= 2'b01;
                addr <= LSB_reg_rs1 + LSB_imm;
                OP_ID <= LSB_OP_ID;
                ROB_id <= LSB_ROB_id;
                // ROB
                ROB_ouptut_valid <= `False;
                // MC
                MC_need_load <= `True;
                MC_OP_ID <= LSB_OP_ID;
                MC_load_addr <= LSB_reg_rs1 + LSB_imm;    
            end
        end
        else if(status == 2'b01) begin // load 
            if(MC_finish_load == `True) begin
                status <= 2'b00;
                // ROB
                ROB_ouptut_valid <= `True;
                ROB_ROB_id <= ROB_id;
                ROB_value <= MC_value;
                ROB_addr <= addr;
                // MC
                MC_need_load <= `False;
            end
            else begin
                // ROB
                ROB_ouptut_valid <= `False;
                // MC
                MC_need_load <= `False;
            end
        end
        else if(status == 2'b10) begin // store
            if(MC_MSB_is_full == `True) begin // 病态操作，从根本上防止发射
                // ROB
                ROB_ouptut_valid <= `False;
                // MC
                MC_need_load <= `False;
            end
            else begin
                status <= 2'b00;
                // ROB
                ROB_ouptut_valid <= `True;
                ROB_ROB_id <= ROB_id;
                ROB_value <= value;
                ROB_addr <= addr;
                // MC
                MC_need_load <= `False;
            end
        end
        else begin // no input && status == 2'b00;
            // ROB
            ROB_ouptut_valid <= `False;
            // MC
            MC_need_load <= `False;
        end
    end
    else begin
        status <= 2'b00;
        addr <= {32{1'b0}};
        value <= {32{1'b0}};
        OP_ID <= {6{1'b0}};
        ROB_id <= {4{1'b0}};
        // ROB
        ROB_ouptut_valid <=`False;
        // MC
        MC_need_load <= `False;
    end
end

endmodule