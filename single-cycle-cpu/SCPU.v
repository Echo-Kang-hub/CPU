`timescale 1ns / 1ps

// 37条指令
module SCPU(
    input  clk,
    input  reset,
    input  [31:0] inst_in,
    input  [31:0] Data_in,
    output mem_w,
    output [31:0] PC_out,
    output [31:0] Addr_out,
    output [31:0] Data_out,
    input  [4:0]  reg_sel,
    output [31:0] reg_data
);


wire [31:0] instr;
reg [31:0] reg_data;
reg [31:0] alu_disp_data;
reg [31:0] dmem_data;

// PC
wire [31:0] PC;
wire [31:0] NPC;
wire PCwr = ~sw_i[1];
wire [2:0] NPCOp;

// ROM
reg [5:0] rom_addr;

// RF
wire RegWrite;
wire [31:0] WD;
wire [31:0] RD1,RD2;

reg [5:0] reg_addr; // 显示用

// ALU
wire [31:0] A,B;
wire [4:0] ALUOp;
wire [31:0] aluout;
wire Zero;

reg [2:0] alu_addr;

// DM
wire MemWrite;
wire [5:0] dm_addr;
wire [31:0] dm_din;
wire [2:0] DMType;
wire [31:0] dm_dout;

reg [6:0] dmem_addr; // 显示用

// Ctrl
wire [5:0] EXTOp;
wire [1:0] WDSel;
wire ALUSrc;

// EXT
wire [31:0] immout;

always @(sw_i) begin
    if(sw_i[0] == 0) begin
        case(sw_i[14:11])
            4'b1000 : display_data <= instr;
            4'b0100 : display_data <= reg_data;
            4'b0010 : display_data <= alu_disp_data;
            4'b0001 : display_data <= dmem_data;
            default : display_data <= instr;
        endcase
    end
    else display_data = led_disp_data;
end

// 例化显示模块
seg7x16 u_seg7x16(
    .clk(clk),
    .rstn(rstn),
    .disp_mode(sw_i[0]),
    .i_data(display_data),
    .disp_seg_o(disp_seg_o),
    .disp_an_o(disp_an_o)
);
///////////////////////////////////////////////////////

// 例化PC_Unit module 时序逻辑
PC_Unit U_PC(.clk(Clk_CPU),.rst(~rstn),.NPC(NPC),.PCwr(PCwr),.PC(PC));

// 例化NPC_Unit module 组合逻辑
NPC_Unit U_NPC(.PC(PC),.NPCOp(NPCOp),.IMM(immout),.aluout(aluout),.NPC(NPC));

// 例化ROM模块
dist_mem_im U_IM(
    .a(rom_addr),
    .spo(instr)
);

// 每个CLK_CPU获得一个新指令
// 关注上升沿：上升沿PC更新为NPC，所以rom_addr也应更新为NPC以取下条指令
 always @(posedge Clk_CPU or negedge rstn) begin
     if(!rstn) rom_addr <= 6'b0;
     else if(sw_i[1] == 1'b0) rom_addr <= NPC >> 2; // rom以1为单位，指令以4为单位，所以除以4以映射rom
     else rom_addr <= rom_addr;
 end

//Decode
wire [6:0]  Op        = instr[6:0];
wire [6:0]  Funct7    = instr[31:25];
wire [2:0]  Funct3    = instr[14:12];
wire [4:0]  rs1       = instr[19:15];
wire [4:0]  rs2       = instr[24:20];
wire [4:0]  rd        = instr[11:7];
wire [4:0]  iimm_shamt= instr[24:20];
wire [11:0] iimm      = instr[31:20]; // jalr, load, itype
wire [11:0] simm      = {instr[31:25],instr[11:7]};
wire [11:0] bimm      = {instr[31],instr[7],instr[30:25],instr[11:8]};
wire [19:0] uimm      = instr[31:12]; // lui, auipc
wire [19:0] jimm      = {instr[31],instr[19:12],instr[20],instr[30:21]}; // jal


// 例化ctrl模块 组合逻辑
ctrl u_ctrl(
    .Op(Op),
    .Funct7(Funct7),
    .Funct3(Funct3),
    .Zero(Zero),
    .RegWrite(RegWrite),
    .MemWrite(MemWrite),
    .EXTOp(EXTOp),
    .ALUOp(ALUOp),
    .ALUSrc(ALUSrc),
    .NPCOp(NPCOp),
    .DMType(DMType),
    .WDSel(WDSel)
);

// 例化EXT模块 组合逻辑
EXT U_EXT(
    .iimm_shamt(iimm_shamt),
    .iimm(iimm),
    .simm(simm),
    .bimm(bimm),
    .uimm(uimm),
    .jimm(jimm),
    .EXTOp(EXTOp),
    .immout(immout)
);


// 赋值

// ALU_DM->RF RF_WD
// WDSel FromALU 2'b00
// WDSel FromMEM 2'b01
// WDSel FromPC 2'b10
//always @(*) begin
//    WD <= 32'h0;
//	case(WDSel)
//		00: WD <= aluout;
//		01: WD <= dm_dout;
//		10: WD <= PC + 4;
//		default: WD <= 32'h0;
//	endcase
//end

// WDSel FromALU 2'b00
// WDSel FromMEM 2'b01
// WDSel FromPC 2'b10
assign WD = (WDSel == 2'b10) ? (PC + 4) :
            (WDSel == 2'b01) ? dm_dout : 
            (WDSel == 2'b00) ? aluout : 32'h00000000;

// RF->ALU ALU_A_B
assign A = RD1;
assign B = (ALUSrc == 1'b0)?RD2:immout;

// ALU->DM DM_addr_din
assign dm_addr = aluout;
assign dm_din = RD2;


// 例化RF模块 时序逻辑
RF U_RF(
    .clk(Clk_CPU),
    .rstn(rstn),
    .RFWr(RegWrite),
    .sw_i(sw_i),
    .A1(rs1),
    .A2(rs2),
    .A3(rd),
    .WD(WD),
    .RD1(RD1),
    .RD2(RD2)
);

// 循环显示32个寄存器的内容
always @(posedge Clk_CPU or negedge rstn) begin
    if(!rstn) begin
        reg_addr <= 5'b0;
        reg_data <= 32'b0;
    end 
    else if(sw_i[13] == 1'b1)begin
        reg_addr <= reg_addr + 1'b1;
        reg_data <= U_RF.rf[reg_addr];
    end
end

/////////////////////////////////////////////////////

// 例化alu模块 组合逻辑
alu U_alu(
    .A(A),
    .B(B),
    .ALUOp(ALUOp),
    .C(aluout),
    .Zero(Zero)
);

// 循环显示A B Zero四个值
always @(posedge Clk_CPU or negedge rstn) begin
    if(!rstn) alu_addr <= 3'b0;
    else alu_addr <= alu_addr + 1'b1;
    case(alu_addr) // 下面用普通reg接收signed数据，只会数据位复制
        3'b001:alu_disp_data <= U_alu.A;
        3'b010:alu_disp_data <= U_alu.B;
        3'b011:alu_disp_data <= U_alu.C;
        3'b100:alu_disp_data <= U_alu.Zero;
        default:alu_disp_data <= 32'hFFFFFFFF;
    endcase
end

//////////////////////////////////////////////////////

// 例化dm模块 时序逻辑
dm U_DM(
    .clk(Clk_CPU),
    .DMWr(MemWrite),
    .addr(dm_addr),
    .din(dm_din),
    .DMType(DMType),
    .dout(dm_dout)
);

// 循环显示Data Memory内容
parameter DM_DATA_NUM = 16;
always @(posedge Clk_CPU or negedge rstn) begin
    if(!rstn) begin
        dmem_addr <= 7'b0;
        dmem_data <= 32'hFFFFFFFF;
    end
    else if(sw_i[11] == 1'b1) begin
        dmem_addr <= dmem_addr + 1'b1;
        dmem_data <= U_DM.dmem[dmem_addr][7:0];
        if(dmem_addr == DM_DATA_NUM) begin // DM_DATA_NUM是不能取到的，所以此时马上切为0
            dmem_addr <= 7'd0;
            dmem_data <= 32'hFFFFFFFF;
        end
    end
end

endmodule 