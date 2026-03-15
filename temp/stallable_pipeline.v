`include "definition.vh"

// 五级流水线 RISC-V CPU
// I0: LUI/AUIPC 
// I3: ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI）
// 接口保持与框架一致：datain[31:0] 为指令，dataout[31:0] 为 WB 写回值，dataout[36:32] 为 rd
// 五级：IF → ID → EX → MA → WB

module stallable_pipeline #(
	parameter WIDTH = `PR_DATA_WIDTH
)(
	input 			clk,
	input			rst,
	input			validin,
	input [WIDTH-1:0]	datain,
	input 			out_allow,
	output			validout,
	output[WIDTH-1:0]	dataout
);

// regfile
reg [31:0] regfile [31:0];
integer i;
always @(posedge clk or posedge rst) begin
	if (rst) begin
		for (i = 0; i < 32; i = i + 1)
			regfile[i] <= i;  // 复位时初始化为寄存器下标
	end
end

// 流水线寄存器有效位
reg  IF_ID_valid; // IF/ID  寄存器
reg  ID_EX_valid; // ID/EX  寄存器
reg  EX_MA_valid; // EX/MEM 寄存器
reg  MA_WB_valid; // MEM/WB 寄存器

// IF 级：接收指令（datain[31:0]）和 PC（datain[63:32]）
// IF/ID 流水线寄存器
reg [31:0] IF_ID_instr;
reg [31:0] IF_ID_pc;

wire IF_ID_allowin;
wire IF_ID_ready_go;
wire IFID_to_IDEX_valid;

assign IF_ID_ready_go      = 1'b1;
assign IF_ID_allowin       = !IF_ID_valid || (IF_ID_ready_go && ID_EX_allowin);
assign IFID_to_IDEX_valid = IF_ID_valid && IF_ID_ready_go;

always @(posedge clk or posedge rst) begin
	if (rst) begin
		IF_ID_valid  <= 1'b0;
		IF_ID_instr  <= 32'b0;
		IF_ID_pc     <= 32'b0;
	end else begin
		if (IF_ID_allowin)
			IF_ID_valid <= validin;
		if (validin && IF_ID_allowin) begin
			IF_ID_instr <= datain[31:0];
			IF_ID_pc    <= datain[63:32];
		end
	end
end

// ID 级：译码、立即数扩展、读寄存器
// Decode
wire [6:0]  id_op     = IF_ID_instr[6:0];
wire [4:0]  id_rd     = IF_ID_instr[11:7];
wire [2:0]  id_funct3 = IF_ID_instr[14:12];
wire [4:0]  id_rs1    = IF_ID_instr[19:15];
wire [6:0]  id_funct7 = IF_ID_instr[31:25];
wire [4:0]  id_shamt  = IF_ID_instr[24:20];
wire [11:0] id_iimm   = IF_ID_instr[31:20];
wire [19:0] id_uimm   = IF_ID_instr[31:12];

// 指令类型识别
wire id_itype_r = (id_op == 7'b0010011); // ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI
wire id_lui     = (id_op == 7'b0110111); // LUI
wire id_auipc   = (id_op == 7'b0010111); // AUIPC

// I3 移位指令
wire id_slli  = id_itype_r & (id_funct3 == 3'b001);
wire id_srli  = id_itype_r & (id_funct3 == 3'b101) & (id_funct7[5] == 1'b0);
wire id_srai  = id_itype_r & (id_funct3 == 3'b101) & (id_funct7[5] == 1'b1);
wire id_shift = id_slli | id_srli | id_srai;

// 立即数扩展
reg [31:0] id_imm;
always @(*) begin
	if (id_lui || id_auipc)
		id_imm = {id_uimm, 12'b0};            // U型立即数
	else if (id_shift)
		id_imm = {27'b0, id_shamt};            // 移位量
	else
		id_imm = {{20{id_iimm[11]}}, id_iimm}; // I型符号扩展
end

// ALUOp 编码（与 alu.v 保持一致）
reg [4:0] id_aluop;
always @(*) begin
	if (id_lui)
		id_aluop = 5'b00011; // add（LUI: 0+imm，A选0）
	else if (id_auipc)
		id_aluop = 5'b00011; // add（AUIPC: PC+imm）
	else begin
		case (id_funct3)
			3'b000: id_aluop = 5'b00011; // addi: add
			3'b010: id_aluop = 5'b00111; // slti: slt
			3'b011: id_aluop = 5'b01010; // sltiu: sltu
			3'b100: id_aluop = 5'b01001; // xori: xor
			3'b110: id_aluop = 5'b01011; // ori: or
			3'b111: id_aluop = 5'b01111; // andi: and
			3'b001: id_aluop = 5'b00001; // slli: sll
			3'b101: id_aluop = id_funct7[5] ? 5'b00101 : 5'b00010; // srai/srli
			default: id_aluop = 5'b00000;
		endcase
	end
end

// RegWrite 控制（上述所有指令均写寄存器）
wire id_regwrite = id_itype_r | id_lui | id_auipc;

// ALUSrcA：LUI 时 A=0，AUIPC 时 A=PC，其余 A=RS1
// 用 [1:0] 编码：00=RS1值，01=PC，10=0
wire [1:0] id_alusrca = id_lui   ? 2'b10 :
                        id_auipc ? 2'b01 :
                                   2'b00;

// 读寄存器（LUI/AUIPC 不需要读 rs1，但为简单起见还是读）
wire [31:0] id_rdata1 = (id_rs1 == 5'b0) ? 32'b0 : regfile[id_rs1];

// ID/EX 流水线寄存器
reg [31:0] ID_EX_pc;
reg [31:0] ID_EX_rdata1;
reg [31:0] ID_EX_imm;
reg [4:0]  ID_EX_aluop;
reg [1:0]  ID_EX_alusrca;
reg [4:0]  ID_EX_rd;
reg        ID_EX_regwrite;

wire ID_EX_allowin;
wire ID_EX_ready_go;
wire IDEX_to_EXMA_valid;

assign ID_EX_ready_go      = 1'b1;
assign ID_EX_allowin       = !ID_EX_valid || (ID_EX_ready_go && EX_MA_allowin);
assign IDEX_to_EXMA_valid  = ID_EX_valid && ID_EX_ready_go;

always @(posedge clk or posedge rst) begin
	if (rst) begin
		ID_EX_valid      <= 1'b0;
		ID_EX_pc         <= 32'b0;
		ID_EX_rdata1     <= 32'b0;
		ID_EX_imm        <= 32'b0;
		ID_EX_aluop      <= 5'b0;
		ID_EX_alusrca    <= 2'b0;
		ID_EX_rd         <= 5'b0;
		ID_EX_regwrite   <= 1'b0;
	end else begin
		if (ID_EX_allowin)
			ID_EX_valid <= IF_ID_valid;
		if (IFID_to_IDEX_valid && ID_EX_allowin) begin
			ID_EX_pc       <= IF_ID_pc;
			ID_EX_rdata1   <= id_rdata1;
			ID_EX_imm      <= id_imm;
			ID_EX_aluop    <= id_aluop;
			ID_EX_alusrca  <= id_alusrca;
			ID_EX_rd       <= id_rd;
			ID_EX_regwrite <= id_regwrite;
		end
	end
end

// EX 级（Stage 3）：ALU 运算
// ALU A 端选择
wire [31:0] ex_alu_a = (ID_EX_alusrca == 2'b10) ? 32'b0         // LUI: A=0
                     : (ID_EX_alusrca == 2'b01) ? ID_EX_pc       // AUIPC: A=PC
                     :                             ID_EX_rdata1;  // 其余: A=RS1

wire [31:0] ex_alu_b = ID_EX_imm; // B 端始终为立即数

// ALU 运算（内联，与 alu.v 逻辑一致）
reg [31:0] ex_aluout;
always @(*) begin
	case (ID_EX_aluop)
		5'b00001: ex_aluout = ex_alu_a << ex_alu_b[4:0];                            // sll
		5'b00010: ex_aluout = ex_alu_a >> ex_alu_b[4:0];                            // srl
		5'b00101: ex_aluout = $signed(ex_alu_a) >>> ex_alu_b[4:0];                  // sra
		5'b00011: ex_aluout = ex_alu_a + ex_alu_b;                                  // add
		5'b01111: ex_aluout = ex_alu_a & ex_alu_b;                                  // and
		5'b01011: ex_aluout = ex_alu_a | ex_alu_b;                                  // or
		5'b01001: ex_aluout = ex_alu_a ^ ex_alu_b;                                  // xor
		5'b00111: ex_aluout = ($signed(ex_alu_a) < $signed(ex_alu_b)) ? 32'd1 : 32'd0; // slt
		5'b01010: ex_aluout = (ex_alu_a < ex_alu_b) ? 32'd1 : 32'd0;               // sltu
		default:  ex_aluout = 32'b0;
	endcase
end

// EX/MA 流水线寄存器
reg [31:0] EX_MA_aluout;
reg [4:0]  EX_MA_rd;
reg        EX_MA_regwrite;

wire EX_MA_allowin;
wire EX_MA_ready_go;
wire EXMA_to_MAWB_valid;

assign EX_MA_ready_go      = 1'b1;
assign EX_MA_allowin       = !EX_MA_valid || (EX_MA_ready_go && MA_WB_allowin);
assign EXMA_to_MAWB_valid  = EX_MA_valid && EX_MA_ready_go;

always @(posedge clk or posedge rst) begin
	if (rst) begin
		EX_MA_valid        <= 1'b0;
		EX_MA_aluout      <= 32'b0;
		EX_MA_rd          <= 5'b0;
		EX_MA_regwrite    <= 1'b0;
	end else begin
		if (EX_MA_allowin)
			EX_MA_valid <= IDEX_to_EXMA_valid;
		if (IDEX_to_EXMA_valid && EX_MA_allowin) begin
			EX_MA_aluout   <= ex_aluout;
			EX_MA_rd       <= ID_EX_rd;
			EX_MA_regwrite <= ID_EX_regwrite;
		end
	end
end

// MA 级：本批指令无内存读写，直接传递
// MA/WB 流水线寄存器
reg [31:0] MA_WB_result;
reg [4:0]  MA_WB_rd;
reg        MA_WB_regwrite;

wire MA_WB_allowin;
wire MA_WB_ready_go;

assign MA_WB_ready_go = 1'b1;
assign MA_WB_allowin  = !MA_WB_valid || (MA_WB_ready_go && out_allow);

always @(posedge clk or posedge rst) begin
	if (rst) begin
		MA_WB_valid     <= 1'b0;
		MA_WB_result   <= 32'b0;
		MA_WB_rd       <= 5'b0;
		MA_WB_regwrite <= 1'b0;
	end else begin
		if (MA_WB_allowin)
			MA_WB_valid <= EXMA_to_MAWB_valid;
		if (EXMA_to_MAWB_valid && MA_WB_allowin) begin
			MA_WB_result   <= EX_MA_aluout;
			MA_WB_rd       <= EX_MA_rd;
			MA_WB_regwrite <= EX_MA_regwrite;
		end
	end
end

// WB：从 MEM/WB 寄存器直接写回，无独立 valid 寄存器

// 写回寄存器堆（MEM/WB 寄存器有效时同步写）
always @(posedge clk) begin
	if (!rst && MA_WB_valid && MA_WB_regwrite && (MA_WB_rd != 5'b0))
		regfile[MA_WB_rd] <= MA_WB_result;
end

// 输出：validout 和 dataout
// dataout[31:0]  = WB 写回值（ALU 结果）
// dataout[36:32] = rd（目标寄存器）
// dataout[37]    = RegWrite
// 其余位为 0
assign validout = MA_WB_valid && MA_WB_ready_go;
assign dataout  = {{(WIDTH-38){1'b0}}, MA_WB_regwrite, MA_WB_rd, MA_WB_result};

endmodule