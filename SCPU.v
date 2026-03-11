// 五级流水线 RISC-V CPU
// I0: LUI/AUIPC；
// I3: ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI
// I4: ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND

// todo：NPCOp的替换或其他

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
    
    // PC / NPC
    wire [31:0] PC, NPC;

    PC_Unit U_PC(
        .clk(clk), .rst(reset),
        .NPC(NPC), .PCwr(1'b1), 
        .PC(PC)
    );
    assign PC_out = PC;

    // NPC generation: branch/jal/jalr
    // NPCOp from ctrl (ID stage); aluout forwarded from EX/MA register
    PC_mux U_PC_mux(
        .branch(branch), .jump(jump), .PC(PC), .IMM(MA_pcimm), .aluout(MA_aluout),
        .NPC(NPC)
    );

    // IF/ID 流水线寄存器：接收指令inst_in和 PC(内部)，传出PC和instr
    reg [31:0] IF_ID_pc;
    reg [31:0] IF_ID_instr;
  
    wire IF_ID_allowin;
    wire IF_ID_ready_go;
    wire IFID_to_IDEX_valid;

    assign IF_ID_ready_go     = 1'b1;
    assign IF_ID_allowin      = !IF_ID_valid || (IF_ID_ready_go && ID_EX_allowin);
    assign IFID_to_IDEX_valid = IF_ID_valid && IF_ID_ready_go;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            IF_ID_valid <= 1'b0;
            IF_ID_pc    <= 32'b0;
            IF_ID_instr <= 32'b0;
        end 
        else begin
            if (IF_ID_allowin) begin
                IF_ID_valid <= 1'b1;  
                IF_ID_pc    <= PC;          
                IF_ID_instr <= inst_in;    
            end
        end
    end




    // ID 级：RF模块、EXT模块、Ctrl模块

    // Decode instruction
    wire [31:0] instr   = IF_ID_instr; 

    // to ctrl 
    wire [6:0]  Op      = instr[6:0];
    wire [6:0]  Funct7  = instr[31:25];
    wire [2:0]  Funct3  = instr[14:12];

    // to RF
    wire [4:0]  rs1     = instr[19:15];
    wire [4:0]  rs2     = instr[24:20];

    // to ID/EX
    wire        ID_Funct7 = instr[30];
    wire [2:0]  ID_Funct3 = instr[14:12];
    wire [4:0]  ID_rd     = instr[11:7];


    // Control signals
    wire ID_RegWrite, ID_MemWrite, ID_ALUSrc;
    wire [4:0]  ID_ALUOp;
    wire [2:0]  ID_DMType;
    wire [1:0]  ID_WDSel;

    ctrl u_ctrl(
        .Op(Op), .Funct7(Funct7), .Funct3(Funct3),
        .RegWrite(ID_RegWrite), .MemWrite(ID_MemWrite),
        .ALUOp(ID_ALUOp), .ALUSrc(ID_ALUSrc),
        .DMType(ID_DMType), .WDSel(ID_WDSel)
    );

    // register file
    wire [31:0] ID_RD1, ID_RD2;

    RF U_RF(
        .clk(clk), .rstn(~reset), .RFWr(WB_RegWrite),
        .A1(rs1), .A2(rs2), .A3(WB_rd),
        .WD(WB_WD), .RD1(ID_RD1), .RD2(ID_RD2)
    );

    assign reg_data = (reg_sel == 5'b0) ? 32'b0 : U_RF.rf[reg_sel];

    // immediate extension
    wire [31:0] immout;

    EXT U_EXT(
        .instr(instr), .immout(immout)
    );



    // ID/EX 流水线寄存器：接收RD1，RD2，immout，PC，控制信号，传出RD1，RD2，immout，PC，控制信号
    reg [31:0] ID_EX_pc;

    // from ctrl
    reg [4:0]  ID_EX_ALUOp;
    reg        ID_EX_ALUSrc;
    reg        ID_EX_RegWrite;
    reg [1:0]  ID_EX_WDSel;
    reg        ID_EX_MemWrite;
    reg [2:0]  ID_EX_DMType;

    // from RF
    reg [31:0] ID_EX_RD1;
    reg [31:0] ID_EX_RD2;

    // from EXT
    reg [31:0] ID_EX_imm;

    // from instr
    reg        ID_EX_Funct7;
    reg [2:0]  ID_EX_Funct3;

    // from instr
    reg [4:0]  ID_EX_rd;
    

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
            // from ctrl
            // EX
            ID_EX_ALUOp    <= 5'b0;
            ID_EX_ALUSrc   <= 1'b0;
            // MA
            ID_EX_MemWrite <= 1'b0;
            ID_EX_DMType   <= 3'b0;
            // WB
            ID_EX_rd       <= 5'b0;
            ID_EX_RegWrite <= 1'b0;
            ID_EX_WDSel    <= 2'b0;

            // from RF
            ID_EX_RD1      <= 32'b0;
            ID_EX_RD2      <= 32'b0;
            // from EXT
            ID_EX_imm      <= 32'b0;
            // from instr
            ID_EX_Funct7   <= 1'b0;
            ID_EX_Funct3   <= 3'b0;
            // from instr
            ID_EX_rd       <= 5'b0;
        end 
        else begin
            if (ID_EX_allowin)
                ID_EX_valid <= IF_ID_valid; 
            if (IFID_to_IDEX_valid && ID_EX_allowin) begin
                ID_EX_pc       <= IF_ID_pc;
                // from ctrl
                // EX
                ID_EX_ALUOp    <= ID_ALUOp;
                ID_EX_ALUSrc   <= ID_ALUSrc;
                // MA
                ID_EX_rd       <= ID_rd;
                ID_EX_MemWrite <= ID_MemWrite;
                ID_EX_DMType   <= ID_DMType;
                // WB
                ID_EX_RegWrite <= ID_RegWrite;
                ID_EX_WDSel    <= ID_WDSel;

                // from RF
                ID_EX_RD1      <= ID_RD1;
                ID_EX_RD2      <= ID_RD2;
                // from EXT
                ID_EX_imm      <= immout;
                // from instr
                ID_EX_Funct7   <= ID_Funct7;
                ID_EX_Funct3   <= ID_Funct3;
            end
        end
    end




    // EX 级：ALU模块
    wire [31:0] EX_pc      = ID_EX_pc;

    // to alu
    wire [31:0] EX_RD1     = ID_EX_RD1;
    wire [31:0] EX_RD2     = ID_EX_RD2;
    wire [31:0] EX_imm     = ID_EX_imm;

    // ctrl signals
    wire        EX_ALUSrc  = ID_EX_ALUSrc;
    wire [4:0]  EX_ALUOp   = ID_EX_ALUOp;
    wire [4:0]  EX_rd      = ID_EX_rd;
    wire        EX_RegWrite = ID_EX_RegWrite;
    wire [1:0]  EX_WDSel   = ID_EX_WDSel;
    wire        EX_MemWrite = ID_EX_MemWrite;
    wire [2:0]  EX_DMType  = ID_EX_DMType;

    // ALUSrcA Mux
    ALUSrcA_mux U_ALUSrcA_mux(
        .ForwardingA(ForwardingA), .RD1(EX_RD1),
        .A(A)
    ); 

    // ALUSrcB Mux
    ALUSrcB_mux U_ALUSrcB_mux(
        .ForwardingB(ForwardingB),.ALUSrc(EX_ALUSrc), .RD2(EX_RD2), .imm(EX_imm),
        .B(B)
    ); 
    

    // ALU
    wire EX_Zero;
    wire [31:0] EX_aluout;

    alu U_alu(
        .A(A), .B(B), .ALUOp(EX_ALUOp),
        .C(EX_aluout), .Zero(EX_Zero)
    );

    // some add
    wire [31:0] EX_pc4 = EX_pc + 4;
    wire [31:0] EX_pcimm = EX_pc + EX_imm;

    // EX/MA 流水线寄存器：接收aluout，RD2，控制信号，传出aluout，RD2，控制信号
    // from add
    reg [31:0] EX_MA_pc4; // for jalr/jal
    reg [31:0] EX_MA_pcimm; // for auipc and branch
    
    // from alu
    reg [31:0] EX_MA_aluout;
    reg EX_MA_Zero;
    
    // from ID/EX
    reg [31:0] EX_MA_imm;  // LUI 需要：WDSel=11 时写回立即数
    reg [31:0] EX_MA_RD2; // for store
    reg [4:0]  EX_MA_rd;
    // ctrl from ID/EX
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
            // from add
            EX_MA_pc4      <= 32'b0;
            EX_MA_pcimm    <= 32'b0;
            // from alu
            EX_MA_aluout   <= 32'b0;
            EX_MA_Zero     <= 1'b0;
            // from ID/EX
            EX_MA_imm      <= 32'b0;
            EX_MA_RD2      <= 32'b0;
            EX_MA_rd       <= 5'b0;
            // ctrl from ID/EX
            EX_MA_RegWrite <= 1'b0;
            EX_MA_WDSel    <= 2'b0;
            EX_MA_MemWrite <= 1'b0;
            EX_MA_DMType   <= 3'b0;
        end else begin
            if (EX_MA_allowin)
                EX_MA_valid <= IDEX_to_EXMA_valid;
            if (IDEX_to_EXMA_valid && EX_MA_allowin) begin
                // from add
                EX_MA_pc4      <= EX_pc4;
                EX_MA_pcimm    <= EX_pcimm;
                // from alu
                EX_MA_aluout   <= EX_aluout;
                EX_MA_Zero     <= EX_Zero;
                // from ID/EX
                EX_MA_imm      <= EX_imm;
                EX_MA_RD2      <= EX_RD2;
                EX_MA_rd       <= EX_rd;
                // ctrl from ID/EX
                EX_MA_RegWrite <= EX_RegWrite;
                EX_MA_WDSel    <= EX_WDSel;
                EX_MA_MemWrite <= EX_MemWrite;
                EX_MA_DMType   <= EX_DMType;
            end
        end
    end




    // MA 级：dm模块
    // to PC_mux
    wire [31:0] MA_pcimm   = EX_MA_pcimm;

    // to branch
    wire        MA_Zero    = EX_MA_Zero;

    // to dm
    wire [31:0] MA_aluout  = EX_MA_aluout;
    wire [31:0] MA_RD2     = EX_MA_RD2;

    // to WB_mux
    wire [31:0] MA_imm     = EX_MA_imm;
    wire [31:0] MA_pc4     = EX_MA_pc4;
    wire [4:0]  MA_rd      = EX_MA_rd;

    // ctrl
    wire        MA_RegWrite = EX_MA_RegWrite;
    wire [1:0]  MA_WDSel   = EX_MA_WDSel;
    wire        MA_MemWrite = EX_MA_MemWrite;
    wire [2:0]  MA_DMType  = EX_MA_DMType;



    assign mem_w    = EX_MA_valid && MA_MemWrite;
    assign Addr_out = MA_aluout;
    assign Data_out = MA_RD2;

    // Load 数据处理
    wire [1:0] MA_byte_sel = MA_aluout[1:0];
    reg  [31:0] MA_ReadData;
    always @(*) begin
        case (MA_DMType[1:0])
            2'b00: begin // byte
                case (MA_byte_sel)
                    2'b00: MA_ReadData = EX_MA_DMType[2] ? {24'b0, Data_in[7:0]}   : {{24{Data_in[7]}},  Data_in[7:0]};
                    2'b01: MA_ReadData = EX_MA_DMType[2] ? {24'b0, Data_in[15:8]}  : {{24{Data_in[15]}}, Data_in[15:8]};
                    2'b10: MA_ReadData = EX_MA_DMType[2] ? {24'b0, Data_in[23:16]} : {{24{Data_in[23]}}, Data_in[23:16]};
                    default: MA_ReadData = EX_MA_DMType[2] ? {24'b0, Data_in[31:24]} : {{24{Data_in[31]}}, Data_in[31:24]};
                endcase
            end
            2'b01: // halfword
                MA_ReadData = MA_byte_sel[1]
                    ? (EX_MA_DMType[2] ? {16'b0, Data_in[31:16]} : {{16{Data_in[31]}}, Data_in[31:16]})
                    : (EX_MA_DMType[2] ? {16'b0, Data_in[15:0]}  : {{16{Data_in[15]}}, Data_in[15:0]});
            default: MA_ReadData = Data_in; // word
        endcase
    end

    // MA/WB 流水线寄存器：接收aluout，DMType，控制信号，传出aluout，DMType，控制信号
    // from dm
    reg [31:0] MA_WB_ReadData;
    // from EX/MA
    reg [31:0] MA_WB_aluout;
    reg [31:0] MA_WB_imm;
    reg [31:0] MA_WB_pc4;
    reg [31:0] MA_WB_pcimm;
    reg [4:0]  MA_WB_rd;
    // ctrl from EX/MA
    reg        MA_WB_RegWrite;
    reg [1:0]  MA_WB_WDSel;

    wire MA_WB_allowin;
    wire MA_WB_ready_go;

    assign MA_WB_ready_go = 1'b1;
    assign MA_WB_allowin  = !MA_WB_valid || MA_WB_ready_go;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            MA_WB_valid    <= 1'b0;
            // from dm
            MA_WB_ReadData <= 32'b0;
            // from EX/MA
            MA_WB_aluout   <= 32'b0;
            MA_WB_imm      <= 32'b0;
            MA_WB_pc4      <= 32'b0;
            MA_WB_pcimm    <= 32'b0;
            MA_WB_rd       <= 5'b0;
            // ctrl from EX/MA
            MA_WB_RegWrite <= 1'b0;
            MA_WB_WDSel    <= 2'b0;
        end else begin
            if (MA_WB_allowin)
                MA_WB_valid <= EXMA_to_MAWB_valid;
            if (EXMA_to_MAWB_valid && MA_WB_allowin) begin
                // from dm
                MA_WB_ReadData <= MA_ReadData;
                // from  EX/MA
                MA_WB_aluout   <= MA_aluout;
                MA_WB_imm      <= MA_imm;
                MA_WB_pc4      <= MA_pc4;
                MA_WB_pcimm    <= MA_pcimm;
                MA_WB_rd       <= MA_rd;
                // ctrl from EX/MA 
                MA_WB_RegWrite <= MA_RegWrite;
                MA_WB_WDSel    <= MA_WDSel;
            end
        end
    end

    // WB 级：
    // write to RF
    wire [31:0] WB_imm      = MA_WB_imm;
    wire [31:0] WB_pc4      = MA_WB_pc4;
    wire [31:0] WB_pcimm    = MA_WB_pcimm;
    wire [31:0] WB_ReadData = MA_WB_ReadData;
    wire [31:0] WB_aluout   = MA_WB_aluout;
    // choose RF
    wire [4:0]  WB_rd       = MA_WB_rd;

    // ctrl from MA/WB
    wire [1:0]  WB_WDSel    = MA_WB_WDSel;
    wire        WB_RegWrite = MA_WB_RegWrite;


    // WDSel: 00=aluout (R/I-ALU包含AUIPC), 01=mem(Load), 10=PC+4(JAL/JALR), 11=imm(LUI)
    wire [31:0] WB_WD = (WB_WDSel == 2'b11) ? WB_imm      // LUI: 写回立即数
                      : (WB_WDSel == 2'b10) ? WB_pc4      // JAL/JALR: 写回PC+4
                      : (WB_WDSel == 2'b01) ? WB_ReadData // Load: 写回存储器数据
                      :                        WB_aluout;  // R/I-type/AUIPC: 写回ALU结果

endmodule