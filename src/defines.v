`define True  1'b1
`define False 1'b0

`define InstWidth 32
`define AddrWidth 32
`define RegIndexBus 4 : 0
`define OpIdBus 5 : 0
`define ImmWidth 32
`define OpcodeBus 6 : 0
`define Funct3Bus 2 : 0
`define Funct7Bus 6 : 0
`define DataWidth 32

`define ROBSize 16
`define ROBIDBus 3 : 0
`define ROBIndexBus 3 : 0

`define RSSize 16
`define RSIndexBus 3 : 0

`define RegSize 32

`define PDCSize 256
//define PDCIndexBus 

`define LSBSize 16
`define LSBIndexBus 3 : 0

`define IQSize 16
`define IQIndexBus 3 : 0

`define MSBSize 8
`define MSBIndexBus 2 : 0

`define ICacheSize 256
`define TagWidth 22
`define ICacheIndex 9 : 2

//instruction set
`define NOP     6'd0

`define LUI     6'd1
`define AUIPC   6'd2

`define JAL     6'd3
`define JALR    6'd4

`define BEQ     6'd5
`define BNE     6'd6
`define BLT     6'd7 
`define BGE     6'd8
`define BLTU    6'd9 
`define BGEU    6'd10 

`define LB      6'd11 
`define LH      6'd12 
`define LW      6'd13 
`define LBU     6'd14 
`define LHU     6'd15 
`define SB      6'd16 
`define SH      6'd17 
`define SW      6'd18 

`define ADD     6'd19 
`define SUB     6'd20 
`define SLL     6'd21 
`define SLT     6'd22 
`define SLTU    6'd23 
`define XOR     6'd24 
`define SRL     6'd25 
`define SRA     6'd26
`define OR      6'd27 
`define AND     6'd28

`define ADDI    6'd29
`define SLTI    6'd30
`define SLTIU   6'd31
`define XORI    6'd32
`define ORI     6'd33
`define ANDI    6'd34
`define SLLI    6'd35
`define SRLI    6'd36
`define SRAI    6'd37

//opcode
`define OpcodeBus 6 : 0

`define OPCODE_LUI    7'b0110111
`define OPCODE_AUIPC  7'b0010111
`define OPCODE_JAL    7'b1101111
`define OPCODE_JALR   7'b1100111
`define OPCODE_B      7'b1100011
`define OPCODE_L      7'b0000011
`define OPCODE_S      7'b0100011
`define OPCODE_R      7'b0110011
`define OPCODE_I      7'b0010011

//funct3
`define FUNCT3_JALR    3'b000

`define FUNCT3_BEQ     3'b000
`define FUNCT3_BNE     3'b001
`define FUNCT3_BLT     3'b100
`define FUNCT3_BGE     3'b101
`define FUNCT3_BLTU    3'b110
`define FUNCT3_BGEU    3'b111

`define FUNCT3_LB      3'b000
`define FUNCT3_LH      3'b001
`define FUNCT3_LW      3'b010 
`define FUNCT3_LBU     3'b100 
`define FUNCT3_LHU     3'b101 
`define FUNCT3_SB      3'b000 
`define FUNCT3_SH      3'b001 
`define FUNCT3_SW      3'b010 

`define FUNCT3_ADD     3'b000 
`define FUNCT3_SUB     3'b000 
`define FUNCT3_SLL     3'b001 
`define FUNCT3_SLT     3'b010 
`define FUNCT3_SLTU    3'b011 
`define FUNCT3_XOR     3'b100 
`define FUNCT3_SRL     3'b101 
`define FUNCT3_SRA     3'b101
`define FUNCT3_OR      3'b110 
`define FUNCT3_AND     3'b111

`define FUNCT3_ADDI    3'b000
`define FUNCT3_SLTI    3'b010
`define FUNCT3_SLTIU   3'b011
`define FUNCT3_XORI    3'b100
`define FUNCT3_ORI     3'b110
`define FUNCT3_ANDI    3'b111
`define FUNCT3_SLLI    3'b001
`define FUNCT3_SRLI    3'b101
`define FUNCT3_SRAI    3'b101

//funct7
`define FUNCT7_ADD   7'b0000000
`define FUNCT7_SUB   7'b0100000
`define FUNCT7_SLL   7'b0000000
`define FUNCT7_SLT   7'b0000000
`define FUNCT7_SLTU  7'b0000000
`define FUNCT7_XOR   7'b0000000
`define FUNCT7_SRL   7'b0000000
`define FUNCT7_SRA   7'b0000000
`define FUNCT7_SRLI  7'b0000000
`define FUNCT7_SRAI  7'b0100000
