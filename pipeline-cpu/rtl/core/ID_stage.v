`ifndef __ID_STAGE_V__   
`define __ID_STAGE_V__
`include "definition.vh"

module ID_stage(
    input  wire        clk,
    input  wire        reset,
    input  wire        FLUSH_IFID,

    // from IF
    input  wire        IF_to_ID_valid, 
    input  wire [`IF_to_ID_BUS_WIDTH-1:0] IF_to_ID_bus,
    output wire        ID_allowin,  

    // to EX
    input  wire        EX_allowin, 
    output wire        ID_to_EX_valid,
    output wire [`ID_to_EX_BUS_WIDTH-1:0] ID_to_EX_bus,

    // Write back from WB
    input  wire        WB_RF_write_enable,
    input  wire [4:0]  WB_RF_write_addr,
    input  wire [31:0] WB_RF_write_data,

    // to IF (Branch/Jal/Jalr)
    output wire        Branch_taken,
    output wire [31:0] Branch_target_addr,
    output wire        Jal_taken,
    output wire [31:0] Jal_target_addr,
    output wire        Jalr_taken,
    output wire [31:0] Jalr_target_addr
);
    // receive from IF and store
    reg [`IF_to_ID_BUS_WIDTH-1:0] IF_to_ID_bus_reg;
    reg                           ID_valid;

    wire ID_ready_go = 1'b1; 

    assign ID_allowin = !ID_valid || (ID_ready_go && EX_allowin);
    assign ID_to_EX_valid = ID_valid && ID_ready_go;

    always @(posedge clk or posedge reset) begin
        if (reset) 
            ID_valid <= 1'b0;
        else if (FLUSH_IFID)
            ID_valid <= 1'b0;
        else begin
            if (ID_allowin) 
                ID_valid <= IF_to_ID_valid;
            else if(ID_allowin && IF_to_ID_valid)
                IF_to_ID_bus_reg <= IF_to_ID_bus;
        end 
    end

    wire [31:0] PC_addr;
    wire [31:0] instr;
    assign {PC_addr, instr} = IF_to_ID_bus_reg;

    //Decode
    wire [6:0]  opcode    = instr[6:0];
    wire [6:0]  funct7    = instr[31:25];
    wire [2:0]  funct3    = instr[14:12];
    wire [4:0]  rs1       = instr[19:15];
    wire [4:0]  rs2       = instr[24:20];
    wire [4:0]  rd        = instr[11:7];
    wire [4:0]  iimm_shamt= instr[24:20];
    wire [11:0] iimm      = instr[31:20]; // jalr, load, itype
    wire [11:0] simm      = {instr[31:25],instr[11:7]};
    wire [11:0] bimm      = {instr[31],instr[7],instr[30:25],instr[11:8]};
    wire [19:0] uimm      = instr[31:12]; // lui, auipc
    wire [19:0] jimm      = {instr[31],instr[19:12],instr[20],instr[30:21]}; // jal

    // Control
    wire RegWrite, ALUSrc1, ALUSrc2, MemWrite;
    wire [2:0] EXTOp;
    wire [2:0] BranchOp;
    wire [3:0] ALUOp;
    wire [2:0] DMType;
    wire [1:0] MemtoReg;

    ctrl u_ctrl(
        .Op(opcode),
        .Funct7(funct7),
        .Funct3(funct3),
        .RegWrite(RegWrite),
        .ALUSrc1(ALUSrc1),
        .ALUSrc2(ALUSrc2),
        .MemWrite(MemWrite),
        .EXTOp(EXTOp),
        .BranchOp(BranchOp),
        .ALUOp(ALUOp),
        .DMType(DMType),
        .MemtoReg(MemtoReg)
    );

    // Register File
    wire [31:0] RD1, RD2;
    RF U_RF(
        .clk(clk),
        .reset(reset),
        .RFWrite(WB_RF_write_enable),
        .rs1(rs1),
        .rs2(rs2),
        .rd(WB_RF_write_addr),
        .WriteData(WB_RF_write_data),
        .RD1(RD1),
        .RD2(RD2)
    );

    // Immediate Extension
    wire [31:0] immout;
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
    // Branch calculation
    wire branch_eq = (RD1 == RD2);
    wire branch_ne = (RD1 != RD2);
    wire branch_lt = ($signed(RD1) < $signed(RD2));
    wire branch_ge = ($signed(RD1) >= $signed(RD2));
    wire branch_ltu = ($unsigned(RD1) < $unsigned(RD2));
    wire branch_geu = ($unsigned(RD1) >= $unsigned(RD2));

    assign Branch_taken = ID_valid && (
                          (BranchOp == `Branch_BEQ)  ? branch_eq  :
                          (BranchOp == `Branch_BNE)  ? branch_ne  :
                          (BranchOp == `Branch_BLT)  ? branch_lt  :
                          (BranchOp == `Branch_BGE)  ? branch_ge  :
                          (BranchOp == `Branch_BLTU) ? branch_ltu :
                          (BranchOp == `Branch_BGEU) ? branch_geu : 1'b0);

    assign Branch_target_addr = PC_addr + immout;

    // Jal/Jalr calculation
    assign Jal_taken  = ID_valid && (opcode == 7'b1101111); // jal
    assign Jal_target_addr = PC_addr + immout; // immout换成jimm也行
    assign Jalr_taken = ID_valid && (opcode == 7'b1100111); // jalr
    assign Jalr_target_addr = (RD1 + immout) & 32'hfffffffe; // clear the least significant bit，immout换成iimm也行
    wire [31:0] PC_plus_4 = PC_addr + 4;

    assign ID_to_EX_bus = {
        PC_addr, 
        PC_plus_4,
        RD1, RD2, 
        immout,
        ALUOp, ALUSrc1, ALUSrc2,
        MemWrite, DMType,
        MemtoReg, RegWrite, rd};

endmodule
`endif