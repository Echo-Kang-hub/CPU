// 五级流水线 RISC-V CPU（I0: LUI/AUIPC；I3: ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI）
// 暂不处理数据/控制冒险，无前递，供后续扩展参考
// 寄存器堆：上升沿读（组合）、下降沿写（WB 级 negedge clk）
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

// ============================================================
// 寄存器堆（内联，取代 RF.v，支持上升沿读、下降沿写）
// 上升沿读：assign 组合逻辑，posedge 触发 ID/EX 锁存时已稳定
// 下降沿写：WB 级 negedge clk 写入，保证下一 posedge 时 ID 读到写后新值
//            天然消除 WBID 同寄存器冒险，无需该路前递
// ============================================================
reg [31:0] rf [31:0];
integer rf_i;
always @(posedge clk or posedge reset) begin
    if (reset)
        for (rf_i = 0; rf_i < 32; rf_i = rf_i + 1)
            rf[rf_i] <= rf_i;   // 复位初始化为寄存器编号（与原 RF.v 一致）
end
assign reg_data = (reg_sel == 5'b0) ? 32'b0 : rf[reg_sel];

// ============================================================
// 流水线寄存器有效位
// ============================================================
reg IF_ID_valid; // IF/ID  寄存器
reg ID_EX_valid; // ID/EX  寄存器
reg EX_MA_valid; // EX/MA  寄存器
reg MA_WB_valid; // MA/WB  寄存器

// ============================================================
// IF 级
// ============================================================
wire [31:0] PC, NPC;

// 当前仅支持顺序执行（I0/I3 无跳转），NPC = PC + 4
// 后续添加分支/跳转时替换为 NPC_Unit 实例
assign NPC = PC + 32'd4;

PC_Unit U_PC(
    .clk(clk), .rst(reset),
    .NPC(NPC), .PCwr(1'b1),     // 无 stall，每拍更新
    .PC(PC)
);
assign PC_out = PC;

// IF/ID 流水线寄存器
reg [31:0] IF_ID_instr;
reg [31:0] IF_ID_pc;

wire IF_ID_allowin;
wire IF_ID_ready_go;
wire IFID_to_IDEX_valid;

assign IF_ID_ready_go     = 1'b1;
assign IF_ID_allowin      = !IF_ID_valid || (IF_ID_ready_go && ID_EX_allowin);
assign IFID_to_IDEX_valid = IF_ID_valid && IF_ID_ready_go;

// validin 处理：
// IM 是组合只读存储器（assign dout = ROM[addr]），PC 始终有效，
// 因此 IF 级每拍均提供有效指令，相当于 validin = 1'b1 恒成立。
// 复位释放后第一拍起 IF_ID_valid 直接置 1，无需外部 validin 信号。
always @(posedge clk or posedge reset) begin
    if (reset) begin
        IF_ID_valid <= 1'b0;
        IF_ID_instr <= 32'b0;
        IF_ID_pc    <= 32'b0;
    end else begin
        if (IF_ID_allowin)
            IF_ID_valid <= 1'b1;        // 无 validin，IF 级始终有效
        if (IF_ID_allowin) begin
            IF_ID_instr <= inst_in;     // 锁存 IM 组合输出的指令
            IF_ID_pc    <= PC;          // 锁存本拍 PC（AUIPC 等需要）
        end
    end
end

// ============================================================
// ID 级：译码 + 立即数扩展 + 读寄存器
// ============================================================
wire [6:0] id_Op     = IF_ID_instr[6:0];
wire [4:0] id_rd     = IF_ID_instr[11:7];
wire [2:0] id_Funct3 = IF_ID_instr[14:12];
wire [4:0] id_rs1    = IF_ID_instr[19:15];
wire [4:0] id_rs2    = IF_ID_instr[24:20]; // 同时是 iimm_shamt[4:0]
wire [6:0] id_Funct7 = IF_ID_instr[31:25];

// 控制信号（由 ctrl 模块产生）
wire        id_RegWrite, id_MemWrite, id_ALUSrc, id_ALUSrcA;
wire [2:0]  id_NPCOp;
wire [4:0]  id_ALUOp;
wire [5:0]  id_EXTOp;
wire [2:0]  id_DMType;
wire [1:0]  id_WDSel;

ctrl u_ctrl(
    .Op(id_Op), .Funct7(id_Funct7), .Funct3(id_Funct3),
    .Zero(1'b0),            // I0/I3 无分支，Zero 不参与 NPCOp 判断
    .RegWrite(id_RegWrite), .MemWrite(id_MemWrite),
    .EXTOp(id_EXTOp),      .ALUOp(id_ALUOp),
    .ALUSrc(id_ALUSrc),     .ALUSrcA(id_ALUSrcA),
    .NPCOp(id_NPCOp),       .DMType(id_DMType), .WDSel(id_WDSel)
);

// 立即数扩展
wire [31:0] id_imm;
EXT u_ext(
    .iimm_shamt(id_rs2),
    .iimm(IF_ID_instr[31:20]),
    .simm({IF_ID_instr[31:25], IF_ID_instr[11:7]}),
    .bimm({IF_ID_instr[31], IF_ID_instr[7], IF_ID_instr[30:25], IF_ID_instr[11:8]}),
    .uimm(IF_ID_instr[31:12]),
    .jimm({IF_ID_instr[31], IF_ID_instr[19:12], IF_ID_instr[20], IF_ID_instr[30:21]}),
    .EXTOp(id_EXTOp),
    .immout(id_imm)
);

// 读寄存器（上升沿读：组合逻辑，posedge 锁存 ID/EX 时取到当前 rf 值）
// 下降沿写保证：上一周期 negedge 写入的值在此 posedge 前已稳定，WBID 冒险自然消除
wire [31:0] id_RD1 = (id_rs1 == 5'b0) ? 32'b0 : rf[id_rs1];
wire [31:0] id_RD2 = (id_rs2 == 5'b0) ? 32'b0 : rf[id_rs2];

// ID/EX 流水线寄存器
reg [31:0] ID_EX_pc;
reg [31:0] ID_EX_RD1;
reg [31:0] ID_EX_RD2;
reg [31:0] ID_EX_imm;
reg [4:0]  ID_EX_ALUOp;
reg        ID_EX_ALUSrc;
reg        ID_EX_ALUSrcA;
reg [4:0]  ID_EX_rd;
reg        ID_EX_RegWrite;
reg [1:0]  ID_EX_WDSel;
reg        ID_EX_MemWrite;
reg [2:0]  ID_EX_DMType;

wire ID_EX_allowin;
wire ID_EX_ready_go;
wire IDEX_to_EXMA_valid;

assign ID_EX_ready_go     = 1'b1;
assign ID_EX_allowin      = !ID_EX_valid || (ID_EX_ready_go && EX_MA_allowin);
assign IDEX_to_EXMA_valid = ID_EX_valid && ID_EX_ready_go;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        ID_EX_valid    <= 1'b0;
        ID_EX_pc       <= 32'b0;
        ID_EX_RD1      <= 32'b0;
        ID_EX_RD2      <= 32'b0;
        ID_EX_imm      <= 32'b0;
        ID_EX_ALUOp    <= 5'b0;
        ID_EX_ALUSrc   <= 1'b0;
        ID_EX_ALUSrcA  <= 1'b0;
        ID_EX_rd       <= 5'b0;
        ID_EX_RegWrite <= 1'b0;
        ID_EX_WDSel    <= 2'b0;
        ID_EX_MemWrite <= 1'b0;
        ID_EX_DMType   <= 3'b0;
    end else begin
        if (ID_EX_allowin)
            ID_EX_valid <= IF_ID_valid;         // valid 从前一级传播
        if (IFID_to_IDEX_valid && ID_EX_allowin) begin
            ID_EX_pc       <= IF_ID_pc;
            ID_EX_RD1      <= id_RD1;
            ID_EX_RD2      <= id_RD2;
            ID_EX_imm      <= id_imm;
            ID_EX_ALUOp    <= id_ALUOp;
            ID_EX_ALUSrc   <= id_ALUSrc;
            ID_EX_ALUSrcA  <= id_ALUSrcA;
            ID_EX_rd       <= id_rd;
            ID_EX_RegWrite <= id_RegWrite;
            ID_EX_WDSel    <= id_WDSel;
            ID_EX_MemWrite <= id_MemWrite;
            ID_EX_DMType   <= id_DMType;
        end
    end
end

// ============================================================
// EX 级：ALU 运算
// ============================================================
wire [31:0] ex_A = ID_EX_ALUSrcA ? ID_EX_pc  : ID_EX_RD1; // AUIPC: A=PC；其余: A=rs1
wire [31:0] ex_B = ID_EX_ALUSrc  ? ID_EX_imm : ID_EX_RD2; // 立即数指令: B=imm；R型: B=rs2

wire [31:0] ex_aluout;
wire        ex_Zero;

alu u_alu(
    .A(ex_A), .B(ex_B),
    .ALUOp(ID_EX_ALUOp),
    .C(ex_aluout), .Zero(ex_Zero)
);

// EX/MA 流水线寄存器
reg [31:0] EX_MA_aluout;
reg [31:0] EX_MA_imm;      // LUI 需要：WDSel=11 时写回立即数
reg [31:0] EX_MA_pc4;      // JAL/JALR 需要：WDSel=10 时写回 PC+4（暂备用）
reg [31:0] EX_MA_RD2;      // Store 数据
reg [4:0]  EX_MA_rd;
reg        EX_MA_RegWrite;
reg [1:0]  EX_MA_WDSel;
reg        EX_MA_MemWrite;
reg [2:0]  EX_MA_DMType;

wire EX_MA_allowin;
wire EX_MA_ready_go;
wire EXMA_to_MAWB_valid;

assign EX_MA_ready_go     = 1'b1;
assign EX_MA_allowin      = !EX_MA_valid || (EX_MA_ready_go && MA_WB_allowin);
assign EXMA_to_MAWB_valid = EX_MA_valid && EX_MA_ready_go;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        EX_MA_valid    <= 1'b0;
        EX_MA_aluout   <= 32'b0;
        EX_MA_imm      <= 32'b0;
        EX_MA_pc4      <= 32'b0;
        EX_MA_RD2      <= 32'b0;
        EX_MA_rd       <= 5'b0;
        EX_MA_RegWrite <= 1'b0;
        EX_MA_WDSel    <= 2'b0;
        EX_MA_MemWrite <= 1'b0;
        EX_MA_DMType   <= 3'b0;
    end else begin
        if (EX_MA_allowin)
            EX_MA_valid <= IDEX_to_EXMA_valid;
        if (IDEX_to_EXMA_valid && EX_MA_allowin) begin
            EX_MA_aluout   <= ex_aluout;
            EX_MA_imm      <= ID_EX_imm;
            EX_MA_pc4      <= ID_EX_pc + 32'd4;
            EX_MA_RD2      <= ID_EX_RD2;
            EX_MA_rd       <= ID_EX_rd;
            EX_MA_RegWrite <= ID_EX_RegWrite;
            EX_MA_WDSel    <= ID_EX_WDSel;
            EX_MA_MemWrite <= ID_EX_MemWrite;
            EX_MA_DMType   <= ID_EX_DMType;
        end
    end
end

// ============================================================
// MA 级：内存访问
// EX/MA 寄存器直接驱动外部数据内存接口（I0/I3 无 store/load，接口保留）
// ============================================================
assign mem_w    = EX_MA_valid && EX_MA_MemWrite;
assign Addr_out = EX_MA_aluout;
assign Data_out = EX_MA_RD2;

// Load 数据处理（I0/I3 暂不使用，逻辑保留供后续扩展）
wire [1:0] ma_byte_sel = EX_MA_aluout[1:0];
reg  [31:0] ma_load_data;
always @(*) begin
    case (EX_MA_DMType[1:0])
        2'b00: begin // byte
            case (ma_byte_sel)
                2'b00: ma_load_data = EX_MA_DMType[2] ? {24'b0, Data_in[7:0]}   : {{24{Data_in[7]}},  Data_in[7:0]};
                2'b01: ma_load_data = EX_MA_DMType[2] ? {24'b0, Data_in[15:8]}  : {{24{Data_in[15]}}, Data_in[15:8]};
                2'b10: ma_load_data = EX_MA_DMType[2] ? {24'b0, Data_in[23:16]} : {{24{Data_in[23]}}, Data_in[23:16]};
                default: ma_load_data = EX_MA_DMType[2] ? {24'b0, Data_in[31:24]} : {{24{Data_in[31]}}, Data_in[31:24]};
            endcase
        end
        2'b01: // halfword
            ma_load_data = ma_byte_sel[1]
                ? (EX_MA_DMType[2] ? {16'b0, Data_in[31:16]} : {{16{Data_in[31]}}, Data_in[31:16]})
                : (EX_MA_DMType[2] ? {16'b0, Data_in[15:0]}  : {{16{Data_in[15]}}, Data_in[15:0]});
        default: ma_load_data = Data_in; // word
    endcase
end

// MA/WB 流水线寄存器
reg [31:0] MA_WB_aluout;
reg [31:0] MA_WB_load;
reg [31:0] MA_WB_imm;
reg [31:0] MA_WB_pc4;
reg [4:0]  MA_WB_rd;
reg        MA_WB_RegWrite;
reg [1:0]  MA_WB_WDSel;

wire MA_WB_allowin;
wire MA_WB_ready_go;

assign MA_WB_ready_go = 1'b1;
assign MA_WB_allowin  = !MA_WB_valid || MA_WB_ready_go;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        MA_WB_valid    <= 1'b0;
        MA_WB_aluout   <= 32'b0;
        MA_WB_load     <= 32'b0;
        MA_WB_imm      <= 32'b0;
        MA_WB_pc4      <= 32'b0;
        MA_WB_rd       <= 5'b0;
        MA_WB_RegWrite <= 1'b0;
        MA_WB_WDSel    <= 2'b0;
    end else begin
        if (MA_WB_allowin)
            MA_WB_valid <= EXMA_to_MAWB_valid;
        if (EXMA_to_MAWB_valid && MA_WB_allowin) begin
            MA_WB_aluout   <= EX_MA_aluout;
            MA_WB_load     <= ma_load_data;
            MA_WB_imm      <= EX_MA_imm;
            MA_WB_pc4      <= EX_MA_pc4;
            MA_WB_rd       <= EX_MA_rd;
            MA_WB_RegWrite <= EX_MA_RegWrite;
            MA_WB_WDSel    <= EX_MA_WDSel;
        end
    end
end

// ============================================================
// WB 级：下降沿写寄存器堆
// 时序：posedge  MA/WB 寄存器更新
//       negedge  rf 写入（此后到下一 posedge 之间 rf 已稳定）
//       下一 posedge  ID 级组合读取到写后新值（WBID 冒险自然消除）
//
// WDSel: 00 = aluout（I型/AUIPC）
//        01 = load_data（Load，暂备用）
//        10 = PC+4（JAL/JALR，暂备用）
//        11 = imm（LUI）
// ============================================================
wire [31:0] wb_WD = (MA_WB_WDSel == 2'b11) ? MA_WB_imm    // LUI
                  : (MA_WB_WDSel == 2'b10) ? MA_WB_pc4    // JAL/JALR（暂备用）
                  : (MA_WB_WDSel == 2'b01) ? MA_WB_load   // Load（暂备用）
                  :                           MA_WB_aluout; // I型/AUIPC

always @(negedge clk) begin
    if (!reset && MA_WB_valid && MA_WB_RegWrite && (MA_WB_rd != 5'b0))
        rf[MA_WB_rd] <= wb_WD;
end

endmodule


















// 五级流水线 RISC-V CPU（I0: LUI/AUIPC；I3: ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI）
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

    // 流水线寄存器有效位
    reg  IF_ID_valid; // IF/ID  寄存器
    reg  ID_EX_valid; // ID/EX  寄存器
    reg  EX_MA_valid; // EX/MEM 寄存器
    reg  MA_WB_valid; // MEM/WB 寄存器

    // IF 级：PC更新模块、im模块
    // IF/ID 流水线寄存器：接收指令inst_in和 PC(内部)，传出PC和instr
    reg [31:0] IF_ID_instr;
    reg [31:0] IF_ID_pc;

    wire IF_ID_allowin;
    wire IF_ID_ready_go;
    wire IFID_to_IDEX_valid;

    // PC / NPC
    wire [31:0] PC, NPC;

    PC_Unit U_PC(
        .clk(clk), .rst(reset), // reset 高电平有效
        .NPC(NPC), .PCwr(1'b1), 
        .PC(PC)
    );
    assign PC_out = PC;

    // NPC generation: branch/jal/jalr
    wire [31:0] aluout;

    // immediate extension
    wire [31:0] immout;

    NPC_Unit U_NPC(
        .PC(PC), .NPCOp(NPCOp), .IMM(immout), .aluout(aluout),
        .NPC(NPC)
    );

    assign IF_ID_ready_go      = 1'b1;
    assign IF_ID_allowin       = !IF_ID_valid || (IF_ID_ready_go && ID_EX_allowin);
    assign IFID_to_IDEX_valid = IF_ID_valid && IF_ID_ready_go;

    // 上升沿写
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            IF_ID_valid  <= 1'b0;
            IF_ID_instr  <= 32'b0;
            IF_ID_pc     <= 32'b0;
        end 
        else begin
            if (IF_ID_allowin)
                IF_ID_valid <= validin;
            if (validin && IF_ID_allowin) begin
                IF_ID_instr <= inst_in;
                IF_ID_pc    <= PC;
            end
        end
    end

    // 上升沿读
    always @(posedge clk or posedge reset) begin
        if(reset) begin
            IF_ID_valid  <= 1'b0;
            IF_ID_instr  <= 32'b0;
            IF_ID_pc     <= 32'b0;
        end
    end

    // ID 级：RF模块、EXT模块、Ctrl模块

    // ID/EX 流水线寄存器：接收RD1，RD2，immout，PC，控制信号，传出RD1，RD2，immout，PC，控制信号


    // EX 级：ALU模块

    // EX/MA 流水线寄存器：接收aluout，RD2，控制信号，传出aluout，RD2，控制信号


    // MA 级：dm模块

    // MA/WB 流水线寄存器：接收aluout，DMType，控制信号，传出aluout，DMType，控制信号

    // WB 级：

    // Decode instruction
    wire [31:0] instr = inst_in; 
    wire [6:0]  Op         = instr[6:0];
    wire [6:0]  Funct7     = instr[31:25]; // add/sub/sll/slt/sltu/xor/srl/sra/or/and 10
    wire [2:0]  Funct3     = instr[14:12];
    wire [4:0]  rs1        = instr[19:15];
    wire [4:0]  rs2        = instr[24:20];
    wire [4:0]  rd         = instr[11:7];
    wire [4:0]  iimm_shamt = instr[24:20]; // slli/srli/srai 3
    wire [11:0] iimm       = instr[31:20]; // addi/slti/sltiu/xori/ori/andi + lb/lh/lw/lbu/lhu + jalr 12
    wire [11:0] simm       = {instr[31:25], instr[11:7]}; // sb/sh/sw 3
    wire [11:0] bimm       = {instr[31], instr[7], instr[30:25], instr[11:8]}; // beq/bne/blt/bge/bltu/bgeu 6
    wire [19:0] uimm       = instr[31:12]; // lui/auipc 2
    wire [19:0] jimm       = {instr[31], instr[19:12], instr[20], instr[30:21]}; // jal 1

    // Control signals
    wire RegWrite, MemWrite, ALUSrc, ALUSrcA, Zero;
    wire [2:0]  NPCOp;
    wire [4:0]  ALUOp;
    wire [5:0]  EXTOp;
    wire [2:0]  DMType;
    wire [1:0]  WDSel;

    ctrl u_ctrl(
        .Op(Op), .Funct7(Funct7), .Funct3(Funct3), .Zero(Zero),
        .RegWrite(RegWrite), .MemWrite(MemWrite),
        .EXTOp(EXTOp), .ALUOp(ALUOp), .ALUSrc(ALUSrc), .ALUSrcA(ALUSrcA),
        .NPCOp(NPCOp), .DMType(DMType), .WDSel(WDSel)
    );



    

    EXT U_EXT(
        .iimm_shamt(iimm_shamt), .iimm(iimm), .simm(simm),
        .bimm(bimm), .uimm(uimm), .jimm(jimm),
        .EXTOp(EXTOp), .immout(immout)
    );

    

    // register
    wire [31:0] RD1, RD2, WD;

    RF U_RF(
        .clk(clk), .rstn(~reset),.RFWr(RegWrite),
        .A1(rs1), .A2(rs2), .A3(rd),
        .WD(WD), .RD1(RD1), .RD2(RD2)
    );

    assign reg_data = (reg_sel == 5'b0) ? 32'b0 : U_RF.rf[reg_sel];

    // ALU
    wire [31:0] A = ALUSrcA ? PC : RD1;  // auipc then A=PC
    wire [31:0] B = ALUSrc ? immout : RD2;

    alu U_alu(
        .A(A), .B(B), .ALUOp(ALUOp),
        .C(aluout), .Zero(Zero)
    );

    // load data
    wire [1:0] dm_byte_sel = aluout[1:0];
    reg  [31:0] load_data;
    always @(*) begin
        case (DMType[1:0])
            2'b00: begin // Byte
                case (dm_byte_sel)
                    2'b00: load_data = DMType[2] ? {24'b0, Data_in[7:0]} : {{24{Data_in[7]}},  Data_in[7:0]};
                    2'b01: load_data = DMType[2] ? {24'b0, Data_in[15:8]} : {{24{Data_in[15]}}, Data_in[15:8]};
                    2'b10: load_data = DMType[2] ? {24'b0, Data_in[23:16]} : {{24{Data_in[23]}}, Data_in[23:16]};
                    default: load_data = DMType[2] ? {24'b0, Data_in[31:24]} : {{24{Data_in[31]}}, Data_in[31:24]};
                endcase
            end
            2'b01: begin // half-word
                load_data = dm_byte_sel[1]
                    ? (DMType[2] ? {16'b0, Data_in[31:16]} : {{16{Data_in[31]}}, Data_in[31:16]})
                    : (DMType[2] ? {16'b0, Data_in[15:0]}  : {{16{Data_in[15]}}, Data_in[15:0]});
            end
            default: load_data = Data_in; // word
        endcase
    end

    // Write Register
    // WDSel: 00=aluout, 01=load_data, 10=PC+4(jal/jalr), 11=immout(lui)
    assign WD = (WDSel == 2'b11) ? immout // lui
              : (WDSel == 2'b10) ? (PC + 32'd4) // jal/jalr
              : (WDSel == 2'b01) ? load_data // load: lw/lh/lb/lbu/lhu
              :                    aluout; // add/sub/sll/slt/sltu/xor/srl/sra/or/and + addi/slti/sltiu/xori/ori/andi + slli/srli/srai + auipc

    assign mem_w    = MemWrite;
    assign Addr_out = aluout;    // memory address（aluout）
    assign Data_out = RD2;       // write memory（store then rs2）

endmodule