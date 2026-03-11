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

    // PC / NPC
    wire [31:0] PC, NPC;

    PC_Unit U_PC(
        .clk(clk), .rst(reset),    // reset 高电平有效（sccomp 已取反 rstn）
        .NPC(NPC), .PCwr(1'b1),    // 单周期 CPU，每拍必须更新 PC
        .PC(PC)
    );
    assign PC_out = PC;

    // immediate extension
    wire [31:0] immout;

    EXT U_EXT(
        .iimm_shamt(iimm_shamt), .iimm(iimm), .simm(simm),
        .bimm(bimm), .uimm(uimm), .jimm(jimm),
        .EXTOp(EXTOp), .immout(immout)
    );

    // NPC generation: branch/jal/jalr
    wire [31:0] aluout;

    NPC_Unit U_NPC(
        .PC(PC), .NPCOp(NPCOp), .IMM(immout), .aluout(aluout),
        .NPC(NPC)
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