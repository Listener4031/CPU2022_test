// RISCV32I CPU top module
// port modification allowed for debugging purposes

// `include "/Users/weijie/Desktop/CPU2022/riscv/src/ALU_LS.v"
// `include "/Users/weijie/Desktop/CPU2022/riscv/src/ALU_RS.v"
// `include "/Users/weijie/Desktop/CPU2022/riscv/src/Decoder.v"
// `include "/Users/weijie/Desktop/CPU2022/riscv/src/defines.v"
// `include "/Users/weijie/Desktop/CPU2022/riscv/src/InstFetcher.v"
// `include "/Users/weijie/Desktop/CPU2022/riscv/src/InstQueue.v"
// `include "/Users/weijie/Desktop/CPU2022/riscv/src/LSBuffer.v"
// `include "/Users/weijie/Desktop/CPU2022/riscv/src/MemController.v"
// `include "/Users/weijie/Desktop/CPU2022/riscv/src/Predictor.v"
// `include "/Users/weijie/Desktop/CPU2022/riscv/src/RegFile.v"
// `include "/Users/weijie/Desktop/CPU2022/riscv/src/ReorderBuffer.v"
// `include "/Users/weijie/Desktop/CPU2022/riscv/src/RsvStation.v"

module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

// LSB to ALU_LS
wire LSB_input_valid_to_ALU_LS;
wire [`OpIdBus] LSB_OP_ID_to_ALU_LS;
wire [`DataWidth - 1 : 0] LSB_inst_pc_to_ALU_LS;
wire [`DataWidth - 1 : 0] LSB_reg_rs1_to_ALU_LS;
wire [`DataWidth - 1 : 0] LSB_reg_rs2_to_ALU_LS;
wire [`ImmWidth - 1 : 0] LSB_imm_to_ALU_LS;
wire [`ROBIDBus] LSB_ROB_id_to_ALU_LS;

// MC to ALU_LS
wire MC_MSB_is_full_to_ALU_LS;                   // store
wire MC_finish_load_to_ALU_LS;                  // load
wire [`DataWidth - 1 : 0] MC_value_to_ALU_LS;

// ROB to ALU_LS
wire ROB_roll_back_flag_to_ALU_LS;

// RS to ALU_RS
wire RS_input_valid_to_ALU_RS;
wire [`OpIdBus] RS_OP_ID_to_ALU_RS;
wire [`DataWidth - 1 : 0] RS_inst_pc_to_ALU_RS;
wire [`DataWidth - 1 : 0] RS_reg_rs1_to_ALU_RS;
wire [`DataWidth - 1 : 0] RS_reg_rs2_to_ALU_RS;
wire [`ImmWidth - 1 : 0] RS_imm_to_ALU_RS;
wire [`ROBIDBus] RS_ROB_id_to_ALU_RS;

// ROB to ALU_RS
wire ROB_roll_back_flag_to_ALU_RS;

// ROB to ID
wire ROB_is_full_to_ID;

// RS to ID
wire RS_is_full_to_ID;

// LSB to ID
wire LSB_is_full_to_ID;

// IQ to ID
wire IQ_input_valid_to_ID;                    // `True -> IQ_inst could be used
wire [`InstWidth - 1 : 0] IQ_inst_to_ID;
wire [`AddrWidth - 1 : 0] IQ_inst_pc_to_ID;
wire IQ_predicted_to_jump_to_ID;
wire [`AddrWidth - 1 : 0] IQ_predicted_pc_to_ID;

// ROB to ID
wire ROB_roll_back_flag_to_ID;

// MC to IF
wire MC_input_valid_to_IF;
wire [`InstWidth - 1 : 0] MC_inst_to_IF;

// PDC to IF
wire PDC_need_jump_to_IF;
wire [`AddrWidth - 1 : 0] PDC_predicted_imm_to_IF;

// IQ to IF
wire IQ_is_full_to_IF;                          // `False -> 尝试 fetch

// ROB to IF
wire ROB_roll_back_flag_to_IF;
wire [`AddrWidth - 1 : 0] ROB_roll_back_pc_to_IF;

// ROB to IQ
wire ROB_is_full_to_IQ;

// RS to IQ
wire RS_is_full_to_IQ;

// LSB to IQ
wire LSB_is_full_to_IQ;

// IF to IQ
wire IF_input_valid_to_IQ;
wire [`InstWidth - 1 : 0] IF_inst_to_IQ;
wire [`AddrWidth - 1 : 0] IF_inst_pc_to_IQ;
wire IF_predicted_to_jump_to_IQ;
wire [`AddrWidth - 1 : 0] IF_predicted_pc_to_IQ;

// ID to IQ
wire ID_ready_to_IQ;

// ROB to IQ
wire ROB_roll_back_flag_to_IQ;

// ID to LSB
wire ID_input_valid_to_LSB;
wire [`DataWidth - 1 : 0] ID_inst_pc_to_LSB;
wire [`OpIdBus] ID_OP_ID_to_LSB;
wire [`RegIndexBus] ID_rd_to_LSB;
wire [`ImmWidth - 1 : 0] ID_imm_to_LSB;

// RF to LSB
wire RF_need_rd_flag_to_LSB;
wire RF_rd_valid_to_LSB;
wire [`ROBIDBus] RF_rd_ROB_id_to_LSB;
wire RF_need_rs1_flag_to_LSB;
wire RF_rs1_valid_to_LSB;
wire [`DataWidth - 1 : 0] RF_reg_rs1_to_LSB;
wire [`ROBIDBus] RF_rs1_ROB_id_to_LSB;
wire RF_need_rs2_flag_to_LSB;
wire RF_rs2_valid_to_LSB;
wire [`DataWidth - 1 : 0] RF_reg_rs2_to_LSB;
wire [`ROBIDBus] RF_rs2_ROB_id_to_LSB;

// ROB to LSB
wire [`ROBIDBus] ROB_new_ID_to_LSB;
wire ROB_input_valid_to_LSB;
wire [`RegIndexBus] ROB_update_ROB_id_to_LSB;
wire [`DataWidth - 1 : 0] ROB_value_to_LSB;
wire ROB_head_store_to_launch_to_LSB;
wire [`ROBIndexBus] ROB_head_ROB_id_to_LSB;

// ALU_LS to LSB
wire ALU_ready_to_LSB;

// ROB to LSB
wire ROB_roll_back_flag_to_LSB;

// IF to MC
wire IF_need_fetch_to_MC;
wire [`AddrWidth - 1 : 0] IF_fetch_pc_to_MC;

// ALU_LS to MC
wire ALU_LS_need_load_to_MC;
wire [`OpIdBus] ALU_LS_OP_ID_to_MC;
wire [`AddrWidth - 1 : 0] ALU_LS_addr_to_MC;

// ROB to MC
wire ROB_input_valid_to_MC;
wire [`OpIdBus] ROB_OP_ID_to_MC;
wire [`DataWidth - 1 : 0] ROB_value_to_MC;
wire [`AddrWidth - 1 : 0] ROB_addr_to_MC;

// ROB to MC
wire ROB_roll_back_flag_to_MC;

// IF to PDC
wire [`InstWidth - 1 : 0] IF_inst_to_PDC;
wire [`AddrWidth - 1 : 0] IF_inst_pc_to_PDC;

// ROB to PDC
wire ROB_input_valid_to_PDC;
wire ROB_hit_to_PDC;
wire [`AddrWidth - 1 : 0] ROB_pc_to_PDC;

// ID to RF
wire ID_rd_valid_to_RF;
wire [`RegIndexBus] ID_rd_to_RF;
wire ID_rs1_valid_to_RF;
wire [`RegIndexBus] ID_rs1_to_RF;
wire ID_rs2_valid_to_RF;
wire [`RegIndexBus] ID_rs2_to_RF;

// ROB to RF
wire [`ROBIDBus] ROB_rd_ROB_id_to_RF;
wire ROB_input_valid_to_RF;
wire [`RegIndexBus] ROB_rd_to_RF;
wire [`DataWidth - 1 : 0] ROB_value_to_RF;

// ROB to RF
wire ROB_roll_back_flag_to_RF;

// ID to ROB
wire ID_input_valid_to_ROB;           // `True -> 队尾申请
wire [`AddrWidth - 1 : 0] ID_inst_pc_to_ROB; 
wire [`OpIdBus] ID_OP_ID_to_ROB; 
wire [`RegIndexBus] ID_rd_to_ROB; 
wire ID_predicted_to_jump_to_ROB; 
wire [`AddrWidth - 1 : 0] ID_predicted_pc_to_ROB; 

// ALU_RS to ROB   
wire ALU_RS_input_valid_to_ROB; 
wire [`ROBIDBus] ALU_RS_ROB_id_to_ROB; 
wire [`DataWidth - 1 : 0] ALU_RS_value_to_ROB; 
wire [`AddrWidth - 1 : 0] ALU_RS_targeted_pc_to_ROB; 
wire ALU_RS_jump_flag_to_ROB;                         // 当前指令是不是要跳转

// ALU_LS to ROB
wire ALU_LS_input_valid_to_ROB; 
wire [`ROBIDBus] ALU_LS_ROB_id_to_ROB; 
wire [`DataWidth - 1 : 0] ALU_LS_value_to_ROB; 
wire [`AddrWidth - 1 : 0] ALU_LS_addr_to_ROB; 

// ID to RS
wire ID_input_valid_to_RS;
wire [`DataWidth - 1 : 0] ID_inst_pc_to_RS;
wire [`OpIdBus] ID_OP_ID_to_RS;
wire [`RegIndexBus] ID_rd_to_RS;
wire [`ImmWidth - 1 : 0] ID_imm_to_RS;
    
// ROB to RS
wire [`ROBIDBus] ROB_new_ID_to_RS;
wire ROB_input_valid_to_RS;
wire [`RegIndexBus] ROB_update_ROB_id_to_RS;
wire [`DataWidth - 1 : 0] ROB_value_to_RS;

// RF to RS
wire RF_need_rd_flag_to_RS;
wire RF_rd_valid_to_RS;
wire [`ROBIDBus] RF_rd_ROB_id_to_RS;
wire RF_need_rs1_flag_to_RS;
wire RF_rs1_valid_to_RS;
wire [`DataWidth - 1 : 0] RF_reg_rs1_to_RS;
wire [`ROBIDBus] RF_rs1_ROB_id_to_RS;
wire RF_need_rs2_flag_to_RS;
wire RF_rs2_valid_to_RS;
wire [`DataWidth - 1 : 0] RF_reg_rs2_to_RS;
wire [`ROBIDBus] RF_rs2_ROB_id_to_RS;

// ROB to RS
wire ROB_roll_back_flag_to_RS;

ALU_LS cpu_ALU_LS(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

    // LSBuffer
  .LSB_input_valid(LSB_input_valid_to_ALU_LS),
  .LSB_OP_ID(LSB_OP_ID_to_ALU_LS),
  .LSB_inst_pc(LSB_inst_pc_to_ALU_LS),
  .LSB_reg_rs1(LSB_reg_rs1_to_ALU_LS),
  .LSB_reg_rs2(LSB_reg_rs2_to_ALU_LS),
  .LSB_imm(LSB_imm_to_ALU_LS),
  .LSB_ROB_id(LSB_ROB_id_to_ALU_LS),
  .LSB_enable(ALU_ready_to_LSB),                        // `False -> next cycle LSB_input_valid == `False

    // ReorderBuffer
  .ROB_ouptut_valid(ALU_LS_input_valid_to_ROB),
  .ROB_ROB_id(ALU_LS_ROB_id_to_ROB),
  .ROB_value(ALU_LS_value_to_ROB),
  .ROB_addr(ALU_LS_addr_to_ROB),

    // MemControllor
  .MC_MSB_is_full(MC_MSB_is_full_to_ALU_LS),                   // store
  .MC_finish_load(MC_finish_load_to_ALU_LS),                   // load
  .MC_value(MC_value_to_ALU_LS),
  .MC_need_load(ALU_LS_need_load_to_MC),
  .MC_OP_ID(ALU_LS_OP_ID_to_MC),
  .MC_load_addr(ALU_LS_addr_to_MC),

    // roll back
  .ROB_roll_back_flag(ROB_roll_back_flag_to_ALU_LS)
);

ALU_RS cpu_ALU_RS(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

    // RsvStation
  .RS_input_valid(RS_input_valid_to_ALU_RS),
  .RS_OP_ID(RS_OP_ID_to_ALU_RS),
  .RS_inst_pc(RS_inst_pc_to_ALU_RS),
  .RS_reg_rs1(RS_reg_rs1_to_ALU_RS),
  .RS_reg_rs2(RS_reg_rs2_to_ALU_RS),
  .RS_imm(RS_imm_to_ALU_RS),
  .RS_ROB_id(RS_ROB_id_to_ALU_RS),

    // ReorderBuffer
  .ROB_ouptut_valid(ALU_RS_input_valid_to_ROB),
  .ROB_ROB_id(ALU_RS_ROB_id_to_ROB),
  .ROB_value(ALU_RS_value_to_ROB),
  .ROB_targeted_pc(ALU_RS_targeted_pc_to_ROB), // pc should to be 
  .ROB_jump_flag(ALU_RS_jump_flag_to_ROB),                         // 是否要跳转

    // roll back
  .ROB_roll_back_flag(ROB_roll_back_flag_to_ALU_RS)
);

Decoder cpu_Decoder(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

    // ReorderBuffer
  .ROB_is_full(ROB_is_full_to_ID),

    // RsvStation
  .RS_is_full(RS_is_full_to_ID),

    // LSBuffer
  .LSB_is_full(LSB_is_full_to_ID),

    // InstQueue
  .IQ_input_valid(IQ_input_valid_to_ID),                    // `True -> IQ_inst could be used
  .IQ_inst(IQ_inst_to_ID),
  .IQ_inst_pc(IQ_inst_pc_to_ID),
  .IQ_predicted_to_jump(IQ_predicted_to_jump_to_ID),
  .IQ_predicted_pc(IQ_predicted_pc_to_ID),
  .IQ_enable(ID_ready_to_IQ),
    
    // LSBuffer
  .LSB_output_valid(ID_input_valid_to_LSB),
  .LSB_inst_pc(ID_inst_pc_to_LSB),
  .LSB_OP_ID(ID_OP_ID_to_LSB),
  .LSB_rd(ID_rd_to_LSB),
  .LSB_imm(ID_imm_to_LSB),

    // RegFile
  .RF_rd_valid(ID_rd_valid_to_RF),                      // from RF get ROB_id
  .RF_rd(ID_rd_to_RF),           
  .RF_rs1_valid(ID_rs1_valid_to_RF),
  .RF_rs1(ID_rs1_to_RF),
  .RF_rs2_valid(ID_rs2_valid_to_RF),
  .RF_rs2(ID_rs2_to_RF),

    // RsvStation
  .RS_output_valid(ID_input_valid_to_RS),
  .RS_inst_pc(ID_inst_pc_to_RS),
  .RS_OP_ID(ID_OP_ID_to_RS),
  .RS_rd(ID_rd_to_RS),
  .RS_imm(ID_imm_to_RS),

    // ReorderBuffer
  .ROB_output_valid(ID_input_valid_to_ROB),                    // `False -> 不进队
  .ROB_inst_pc(ID_inst_pc_to_ROB),
  .ROB_OP_ID(ID_OP_ID_to_ROB),
  .ROB_rd(ID_rd_to_ROB),
  .ROB_predicted_to_jump(ID_predicted_to_jump_to_ROB),
  .ROB_predicted_pc(ID_predicted_pc_to_ROB),

    // roll back
  .ROB_roll_back_flag(ROB_roll_back_flag_to_ID)
);

InstFetcher cpu_InstFetcher(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

    // MemControllor
  .MC_input_valid(MC_input_valid_to_IF),
  .MC_inst(MC_inst_to_IF),
  .MC_need_fetch(IF_need_fetch_to_MC),                    // miss -> `True -> MC_fetch
  .MC_fetch_pc(IF_fetch_pc_to_MC),

    // Predictor
  .PDC_need_jump(PDC_need_jump_to_IF),
  .PDC_predicted_imm(PDC_predicted_imm_to_IF),
  .PDC_inst(IF_inst_to_PDC),
  .PDC_inst_pc(IF_inst_pc_to_PDC),

    // InstQueue
  .IQ_is_full(IQ_is_full_to_IF),                          // `False -> 尝试 fetch
  .IQ_output_valid(IF_input_valid_to_IQ),
  .IQ_inst(IF_inst_to_IQ),
  .IQ_inst_pc(IF_inst_pc_to_IQ),
  .IQ_predicted_to_jump(IF_predicted_to_jump_to_IQ),
  .IQ_predicted_pc(IF_predicted_pc_to_IQ),

    // roll back
  .ROB_roll_back_flag(ROB_roll_back_flag_to_IF),
  .ROB_roll_back_pc(ROB_roll_back_pc_to_IF)
);

InstQueue cpu_InstQueue(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

    // ReorderBuffer
  .ROB_is_full(ROB_is_full_to_IQ),

    // RsvStation
  .RS_is_full(RS_is_full_to_IQ),

    // LSBuffer
  .LSB_is_full(LSB_is_full_to_IQ),

    // InstFetcher
  .IF_IQ_is_full(IQ_is_full_to_IF),                        

    // InstFetcher
  .IF_input_valid(IF_input_valid_to_IQ),
  .IF_inst(IF_inst_to_IQ),
  .IF_inst_pc(IF_inst_pc_to_IQ),
  .IF_predicted_to_jump(IF_predicted_to_jump_to_IQ),
  .IF_predicted_pc(IF_predicted_pc_to_IQ),

    // Decoder
  .ID_ready(ID_ready_to_IQ),
  .ID_output_valid(IQ_input_valid_to_ID),
  .ID_inst(IQ_inst_to_ID),
  .ID_inst_pc(IQ_inst_pc_to_ID),
  .ID_predicted_to_jump(IQ_predicted_to_jump_to_ID),
  .ID_predicted_pc(IQ_predicted_pc_to_ID),

    // roll back
  .ROB_roll_back_flag(ROB_roll_back_flag_to_IQ)
);

LSBuffer cpu_LSBuffer(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

    // InstQueue
  .IQ_LSB_is_full(LSB_is_full_to_IQ),

    // Decoder
  .ID_input_valid(ID_input_valid_to_LSB),
  .ID_inst_pc(ID_inst_pc_to_LSB), 
  .ID_OP_ID(ID_OP_ID_to_LSB),
  .ID_rd(ID_rd_to_LSB),
  .ID_imm(ID_imm_to_LSB),
  .ID_LSB_is_full(LSB_is_full_to_ID),

    // RegFile
  .RF_need_rd_flag(RF_need_rd_flag_to_LSB),
  .RF_rd_valid(RF_rd_valid_to_LSB),
  .RF_rd_ROB_id( RF_rd_ROB_id_to_LSB),
  .RF_need_rs1_flag(RF_need_rs1_flag_to_LSB),
  .RF_rs1_valid(RF_rs1_valid_to_LSB),
  .RF_reg_rs1(RF_reg_rs1_to_LSB),
  .RF_rs1_ROB_id(RF_rs1_ROB_id_to_LSB),
  .RF_need_rs2_flag(RF_need_rs2_flag_to_LSB),
  .RF_rs2_valid(RF_rs2_valid_to_LSB),
  .RF_reg_rs2(RF_reg_rs2_to_LSB),
  .RF_rs2_ROB_id(RF_rs2_ROB_id_to_LSB),

    // ReorderBuffer
  .ROB_new_ID(ROB_new_ID_to_LSB),
  .ROB_input_valid(ROB_input_valid_to_LSB),
  .ROB_update_ROB_id(ROB_update_ROB_id_to_LSB),
  .ROB_value(ROB_value_to_LSB),
  .ROB_head_store_to_launch(ROB_head_store_to_launch_to_LSB),
  .ROB_head_ROB_id(ROB_head_ROB_id_to_LSB),

    // ALU_LS
  .ALU_ready(ALU_ready_to_LSB),
  .ALU_output_valid(LSB_input_valid_to_ALU_LS),
  .ALU_OP_ID(LSB_OP_ID_to_ALU_LS),
  .ALU_inst_pc(LSB_inst_pc_to_ALU_LS),
  .ALU_reg_rs1(LSB_reg_rs1_to_ALU_LS),
  .ALU_reg_rs2(LSB_reg_rs2_to_ALU_LS),
  .ALU_imm(LSB_imm_to_ALU_LS),
  .ALU_ROB_id(LSB_ROB_id_to_ALU_LS),

    // roll back
  .ROB_roll_back_flag(ROB_roll_back_flag_to_LSB)
);

MemController cpu_MemController(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

    // cpu
  .uart_buffer_is_full(io_buffer_full),
  .is_write(mem_wr),
  .addr_to_ram(mem_a),
  .data_in(mem_din),
  .data_out(mem_dout),

    // InstFetcher
  .IF_need_fetch(IF_need_fetch_to_MC),
  .IF_fetch_pc(IF_fetch_pc_to_MC),
  .IF_output_valid(MC_input_valid_to_IF),
  .IF_inst(MC_inst_to_IF),

    // ALU_LS
  .ALU_LS_need_load(ALU_LS_need_load_to_MC),
  .ALU_LS_OP_ID(ALU_LS_OP_ID_to_MC),
  .ALU_LS_addr(ALU_LS_addr_to_MC),
  .ALU_LS_MSB_is_full(MC_MSB_is_full_to_ALU_LS),
  .ALU_LS_output_valid(MC_finish_load_to_ALU_LS),
  .ALU_LS_value(MC_value_to_ALU_LS),

    // ReorderBuffer
  .ROB_input_valid(ROB_input_valid_to_MC),
  .ROB_OP_ID(ROB_OP_ID_to_MC),
  .ROB_value(ROB_value_to_MC),
  .ROB_addr(ROB_addr_to_MC),

    // roll back
  .ROB_roll_back_flag(ROB_roll_back_flag_to_MC)
);

Predictor cpu_Predictor(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

    // InstFetcher
  .IF_inst(IF_inst_to_PDC),
  .IF_inst_pc(IF_inst_pc_to_PDC),
  .IF_need_jump(PDC_need_jump_to_IF),
  .IF_predicted_imm(PDC_predicted_imm_to_IF),

    // ReorderBuffer
  .ROB_input_valid(ROB_input_valid_to_PDC),
  .ROB_hit(ROB_hit_to_PDC),
  .ROB_pc(ROB_pc_to_PDC)
);

RegFile cpu_RegFile(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

    // Decoder
  .ID_rd_valid(ID_rd_valid_to_RF),
  .ID_rd(ID_rd_to_RF),
  .ID_rs1_valid(ID_rs1_valid_to_RF),
  .ID_rs1(ID_rs1_to_RF),
  .ID_rs2_valid(ID_rs2_valid_to_RF),
  .ID_rs2(ID_rs2_to_RF),

    // RsvStation
  .RS_need_rd_flag(RF_need_rd_flag_to_RS),
  .RS_rd_valid(RF_rd_valid_to_RS),                      
  .RS_rd_ROB_id(RF_rd_ROB_id_to_RS),
  .RS_need_rs1_flag(RF_need_rs1_flag_to_RS),
  .RS_rs1_valid(RF_rs1_valid_to_RS),                    // `True -> get RS_reg_rs1 (value), `False -> get ROB_id
  .RS_reg_rs1(RF_reg_rs1_to_RS), 
  .RS_rs1_ROB_id(RF_rs1_ROB_id_to_RS),
  .RS_need_rs2_flag(RF_need_rs2_flag_to_RS),
  .RS_rs2_valid(RF_rs2_valid_to_RS),
  .RS_reg_rs2(RF_reg_rs2_to_RS),
  .RS_rs2_ROB_id(RF_rs2_ROB_id_to_RS),

    // LSBuffer
  .LSB_need_rd_flag(RF_need_rd_flag_to_LSB),
  .LSB_rd_valid(RF_rd_valid_to_LSB),
  .LSB_rd_ROB_id(RF_rd_ROB_id_to_LSB),
  .LSB_need_rs1_flag(RF_need_rs1_flag_to_LSB),
  .LSB_rs1_valid(RF_rs1_valid_to_LSB),
  .LSB_reg_rs1(RF_reg_rs1_to_LSB),
  .LSB_rs1_ROB_id(RF_rs1_ROB_id_to_LSB),
  .LSB_need_rs2_flag(RF_need_rs2_flag_to_LSB),
  .LSB_rs2_valid(RF_rs2_valid_to_LSB),
  .LSB_reg_rs2(RF_reg_rs2_to_LSB),
  .LSB_rs2_ROB_id(RF_rs2_ROB_id_to_LSB),

    // ReorderBuffer
  .ROB_rd_ROB_id(ROB_rd_ROB_id_to_RF),
  .ROB_input_valid(ROB_input_valid_to_RF),
  .ROB_rd(ROB_rd_to_RF),
  .ROB_value(ROB_value_to_RF),

    // roll back
  .ROB_roll_back_flag(ROB_roll_back_flag_to_RF)
);

ReorderBuffer cpu_ReorderBuffer(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

    // InstQueue
  .IQ_ROB_is_full(ROB_is_full_to_IQ),

    // Decoder
  .ID_input_valid(ID_input_valid_to_ROB),           // `True -> 队尾申请
  .ID_inst_pc(ID_inst_pc_to_ROB),
  .ID_OP_ID(ID_OP_ID_to_ROB),
  .ID_rd(ID_rd_to_ROB),
  .ID_predicted_to_jump(ID_predicted_to_jump_to_ROB),
  .ID_predicted_pc(ID_predicted_pc_to_ROB),
  .ID_ROB_is_full(ROB_is_full_to_ID),
    
    // RsvStation
  .RS_ROB_id(ROB_new_ID_to_RS),         // new ROB_id for a new RS(当前的)
  .RS_output_valid(ROB_input_valid_to_RS),
  .RS_update_ROB_id(ROB_update_ROB_id_to_RS),
  .RS_value(ROB_value_to_RS),

    // LSBuffer
  .LSB_ROB_id(ROB_new_ID_to_LSB),         // new ROB_id for a new LS(当前的)
  .LSB_output_valid(ROB_input_valid_to_LSB),
  .LSB_update_ROB_id(ROB_update_ROB_id_to_LSB),
  .LSB_value(ROB_value_to_LSB),
  .LSB_head_store_to_launch(ROB_head_store_to_launch_to_LSB),
  .LSB_head_ROB_id(ROB_head_ROB_id_to_LSB),

    // ALU_RS
  .ALU_RS_input_valid(ALU_RS_input_valid_to_ROB),
  .ALU_RS_ROB_id(ALU_RS_ROB_id_to_ROB),
  .ALU_RS_value(ALU_RS_value_to_ROB),
  .ALU_RS_targeted_pc(ALU_RS_targeted_pc_to_ROB),
  .ALU_RS_jump_flag(ALU_RS_jump_flag_to_ROB),                        // 当前指令是不是要跳转

    // ALU_LS
  .ALU_LS_input_valid(ALU_LS_input_valid_to_ROB),
  .ALU_LS_ROB_id(ALU_LS_ROB_id_to_ROB),
  .ALU_LS_value(ALU_LS_value_to_ROB),
  .ALU_LS_addr(ALU_LS_addr_to_ROB),

    // RegFile
  .RF_ROB_id(ROB_rd_ROB_id_to_RF),         // 当前的
  .RF_output_valid(ROB_input_valid_to_RF),
  .RF_rd(ROB_rd_to_RF),
  .RF_value(ROB_value_to_RF),

    // MemControllor
  .MC_output_valid(ROB_input_valid_to_MC),
  .MC_OP_ID(ROB_OP_ID_to_MC),
  .MC_value(ROB_value_to_MC),
  .MC_addr(ROB_addr_to_MC),

    // Predictor
  .PDC_output_valid(ROB_input_valid_to_PDC),
  .PDC_hit(ROB_hit_to_PDC),
  .PDC_inst_pc(ROB_pc_to_PDC),

    // roll back
    // ALU_LS
  .ALU_LS_roll_back_flag(ROB_roll_back_flag_to_ALU_LS),
    // ALU_RS
  .ALU_RS_roll_back_flag(ROB_roll_back_flag_to_ALU_RS),
    // Decoder
  .ID_roll_back_flag(ROB_roll_back_flag_to_ID),
    // InstFetcher
  .IF_roll_back_flag(ROB_roll_back_flag_to_IF),
  .IF_roll_back_pc(ROB_roll_back_pc_to_IF),
    // InstQueue
  .IQ_roll_back_flag(ROB_roll_back_flag_to_IQ),
    // LSBuffer
  .LSB_roll_back_flag(ROB_roll_back_flag_to_LSB),
    // MemControllor
  .MC_roll_back_flag(ROB_roll_back_flag_to_MC),
    // RegFile
  .RF_roll_back_flag(ROB_roll_back_flag_to_RF),
    // RsvStation
  .RS_roll_back_flag(ROB_roll_back_flag_to_RS)
);

RsvStation cpu_RsvStation(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

    // InstQueue
  .IQ_RS_is_full(RS_is_full_to_IQ),
    
    // Decoder
  .ID_input_valid(ID_input_valid_to_RS),
  .ID_inst_pc(ID_inst_pc_to_RS),
  .ID_OP_ID(ID_OP_ID_to_RS),
  .ID_rd(ID_rd_to_RS),
  .ID_imm(ID_imm_to_RS),
  .ID_RS_is_full(RS_is_full_to_ID),
    
    // ReorderBuffer
  .ROB_new_ID(ROB_new_ID_to_RS),
  .ROB_input_valid(ROB_input_valid_to_RS),
  .ROB_update_ROB_id(ROB_update_ROB_id_to_RS),
  .ROB_value(ROB_value_to_RS),

    // RegFile
  .RF_need_rd_flag(RF_need_rd_flag_to_RS),
  .RF_rd_valid(RF_rd_valid_to_RS),
  .RF_rd_ROB_id(RF_rd_ROB_id_to_RS),
  .RF_need_rs1_flag(RF_need_rs1_flag_to_RS),
  .RF_rs1_valid(RF_rs1_valid_to_RS),
  .RF_reg_rs1(RF_reg_rs1_to_RS),
  .RF_rs1_ROB_id(RF_rs1_ROB_id_to_RS),
  .RF_need_rs2_flag(RF_need_rs2_flag_to_RS),
  .RF_rs2_valid(RF_rs2_valid_to_RS),
  .RF_reg_rs2(RF_reg_rs2_to_RS),
  .RF_rs2_ROB_id(RF_rs2_ROB_id_to_RS),

    // ALU_RS
  .ALU_output_valid(RS_input_valid_to_ALU_RS),
  .ALU_OP_ID(RS_OP_ID_to_ALU_RS),
  .ALU_inst_pc(RS_inst_pc_to_ALU_RS),
  .ALU_reg_rs1(RS_reg_rs1_to_ALU_RS),
  .ALU_reg_rs2(RS_reg_rs2_to_ALU_RS),
  .ALU_imm(RS_imm_to_ALU_RS),
  .ALU_ROB_id(RS_ROB_id_to_ALU_RS),

    // roll back
  .ROB_roll_back_flag(ROB_roll_back_flag_to_RS)
);

endmodule