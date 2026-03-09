`include "definition.vh"

// ============================================================
// 五级流水线 RISC-V CPU（仅支持 I0: LUI/AUIPC 和 I3: ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI）
// 接口保持与框架一致：datain[31:0] 为指令，dataout[31:0] 为 WB 写回值，dataout[36:32] 为 rd
// 五级：IF → ID → EX → MEM → WB
// ============================================================
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

// ============================================================
// 寄存器堆（32个32位寄存器）
// ============================================================
reg [31:0] regfile [31:0];
integer _i;
always @(posedge clk or posedge rst) begin
	if (rst) begin
		for (_i = 0; _i < 32; _i = _i + 1)
			regfile[_i] <= _i;  // 复位时初始化为寄存器下标
	end
end

// ============================================================
// 流水线级间寄存器有效位
// ============================================================
reg  pipe1_valid; // IF
reg  pipe2_valid; // ID
reg  pipe3_valid; // EX
reg  pipe4_valid; // MEM
reg  pipe5_valid; // WB

// ============================================================
// IF 级（Stage 1）：接收指令（datain[31:0]）和 PC（datain[63:32]）
// ============================================================
// IF/ID 流水线寄存器
reg [31:0] if_id_instr;
reg [31:0] if_id_pc;

wire pipe1_allowin;
wire pipe1_ready_go;
wire pipe1_to_pipe2_valid;

assign pipe1_ready_go      = 1'b1;
assign pipe1_allowin       = !pipe1_valid || (pipe1_ready_go && pipe2_allowin);
assign pipe1_to_pipe2_valid = pipe1_valid && pipe1_ready_go;

always @(posedge clk or posedge rst) begin
	if (rst) begin
		pipe1_valid  <= 1'b0;
		if_id_instr  <= 32'b0;
		if_id_pc     <= 32'b0;
	end else begin
		if (pipe1_allowin)
			pipe1_valid <= validin;
		if (validin && pipe1_allowin) begin
			if_id_instr <= datain[31:0];
			if_id_pc    <= datain[63:32];
		end
	end
end

// ============================================================
// ID 级（Stage 2）：译码、立即数扩展、读寄存器
// ============================================================
// 指令字段解码
wire [6:0]  id_op     = if_id_instr[6:0];
wire [4:0]  id_rd     = if_id_instr[11:7];
wire [2:0]  id_funct3 = if_id_instr[14:12];
wire [4:0]  id_rs1    = if_id_instr[19:15];
wire [6:0]  id_funct7 = if_id_instr[31:25];
wire [4:0]  id_shamt  = if_id_instr[24:20];
wire [11:0] id_iimm   = if_id_instr[31:20];
wire [19:0] id_uimm   = if_id_instr[31:12];

// 指令类型识别
wire id_itype_r = (id_op == 7'b0010011); // ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI
wire id_lui     = (id_op == 7'b0110111); // LUI
wire id_auipc   = (id_op == 7'b0010111); // AUIPC

// I3 移位指令（使用 shamt 而非完整立即数）
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
reg [31:0] id_ex_pc;
reg [31:0] id_ex_rdata1;
reg [31:0] id_ex_imm;
reg [4:0]  id_ex_aluop;
reg [1:0]  id_ex_alusrca;
reg [4:0]  id_ex_rd;
reg        id_ex_regwrite;

wire pipe2_allowin;
wire pipe2_ready_go;
wire pipe2_to_pipe3_valid;

assign pipe2_ready_go      = 1'b1;
assign pipe2_allowin       = !pipe2_valid || (pipe2_ready_go && pipe3_allowin);
assign pipe2_to_pipe3_valid = pipe2_valid && pipe2_ready_go;

always @(posedge clk or posedge rst) begin
	if (rst) begin
		pipe2_valid      <= 1'b0;
		id_ex_pc         <= 32'b0;
		id_ex_rdata1     <= 32'b0;
		id_ex_imm        <= 32'b0;
		id_ex_aluop      <= 5'b0;
		id_ex_alusrca    <= 2'b0;
		id_ex_rd         <= 5'b0;
		id_ex_regwrite   <= 1'b0;
	end else begin
		if (pipe2_allowin)
			pipe2_valid <= pipe1_to_pipe2_valid;
		if (pipe1_to_pipe2_valid && pipe2_allowin) begin
			id_ex_pc       <= if_id_pc;
			id_ex_rdata1   <= id_rdata1;
			id_ex_imm      <= id_imm;
			id_ex_aluop    <= id_aluop;
			id_ex_alusrca  <= id_alusrca;
			id_ex_rd       <= id_rd;
			id_ex_regwrite <= id_regwrite;
		end
	end
end

// ============================================================
// EX 级（Stage 3）：ALU 运算
// ============================================================
// ALU A 端选择
wire [31:0] ex_alu_a = (id_ex_alusrca == 2'b10) ? 32'b0         // LUI: A=0
                     : (id_ex_alusrca == 2'b01) ? id_ex_pc       // AUIPC: A=PC
                     :                             id_ex_rdata1;  // 其余: A=RS1

wire [31:0] ex_alu_b = id_ex_imm; // B 端始终为立即数

// ALU 运算（内联，与 alu.v 逻辑一致）
reg [31:0] ex_aluout;
always @(*) begin
	case (id_ex_aluop)
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

// EX/MEM 流水线寄存器
reg [31:0] ex_mem_aluout;
reg [4:0]  ex_mem_rd;
reg        ex_mem_regwrite;

wire pipe3_allowin;
wire pipe3_ready_go;
wire pipe3_to_pipe4_valid;

assign pipe3_ready_go      = 1'b1;
assign pipe3_allowin       = !pipe3_valid || (pipe3_ready_go && pipe4_allowin);
assign pipe3_to_pipe4_valid = pipe3_valid && pipe3_ready_go;

always @(posedge clk or posedge rst) begin
	if (rst) begin
		pipe3_valid        <= 1'b0;
		ex_mem_aluout      <= 32'b0;
		ex_mem_rd          <= 5'b0;
		ex_mem_regwrite    <= 1'b0;
	end else begin
		if (pipe3_allowin)
			pipe3_valid <= pipe2_to_pipe3_valid;
		if (pipe2_to_pipe3_valid && pipe3_allowin) begin
			ex_mem_aluout   <= ex_aluout;
			ex_mem_rd       <= id_ex_rd;
			ex_mem_regwrite <= id_ex_regwrite;
		end
	end
end

// ============================================================
// MEM 级（Stage 4）：本批指令无内存读写，直接传递
// ============================================================
// MEM/WB 流水线寄存器
reg [31:0] mem_wb_result;
reg [4:0]  mem_wb_rd;
reg        mem_wb_regwrite;

wire pipe4_allowin;
wire pipe4_ready_go;
wire pipe4_to_pipe5_valid;

assign pipe4_ready_go      = 1'b1;
assign pipe4_allowin       = !pipe4_valid || (pipe4_ready_go && pipe5_allowin);
assign pipe4_to_pipe5_valid = pipe4_valid && pipe4_ready_go;

always @(posedge clk or posedge rst) begin
	if (rst) begin
		pipe4_valid        <= 1'b0;
		mem_wb_result      <= 32'b0;
		mem_wb_rd          <= 5'b0;
		mem_wb_regwrite    <= 1'b0;
	end else begin
		if (pipe4_allowin)
			pipe4_valid <= pipe3_to_pipe4_valid;
		if (pipe3_to_pipe4_valid && pipe4_allowin) begin
			mem_wb_result   <= ex_mem_aluout;
			mem_wb_rd       <= ex_mem_rd;
			mem_wb_regwrite <= ex_mem_regwrite;
		end
	end
end

// ============================================================
// WB 级（Stage 5）：写回寄存器堆，输出结果
// ============================================================
wire pipe5_allowin;
wire pipe5_ready_go;

assign pipe5_ready_go = 1'b1;
assign pipe5_allowin  = !pipe5_valid || (pipe5_ready_go && out_allow);

always @(posedge clk or posedge rst) begin
	if (rst) begin
		pipe5_valid <= 1'b0;
	end else begin
		if (pipe5_allowin)
			pipe5_valid <= pipe4_to_pipe5_valid;
	end
end

// 写回寄存器堆（同步写，WB级有效且RegWrite有效且rd非0）
always @(posedge clk) begin
	if (!rst && pipe5_valid && mem_wb_regwrite && (mem_wb_rd != 5'b0))
		regfile[mem_wb_rd] <= mem_wb_result;
end

// ============================================================
// 输出：validout 和 dataout
// dataout[31:0]  = WB 写回值（ALU 结果）
// dataout[36:32] = rd（目标寄存器）
// dataout[37]    = RegWrite
// 其余位为 0
// ============================================================
assign validout       = pipe5_valid && pipe5_ready_go;
assign dataout        = {{(WIDTH-38){1'b0}}, mem_wb_regwrite, mem_wb_rd, mem_wb_result};

endmodule