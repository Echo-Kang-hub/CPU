`ifndef __EX_STAGE_V__   
`define __EX_STAGE_V__
`include "definition.vh"

module EX_stage(
    input  wire        clk,
    input  wire        reset,

    // from ID
    input  wire        ID_to_EX_valid,
    input  wire [`ID_to_EX_BUS_WIDTH-1:0] ID_to_EX_bus,
    output wire        EX_allowin,

    // to MA
    input  wire        MA_allowin,
    output wire        EX_to_MA_valid,
    output wire [`EX_to_MA_BUS_WIDTH-1:0] EX_to_MA_bus,

    // forwarding
    input  wire        EXMA_RegWrite,
    input  wire [4:0]  EXMA_rd,
    input  wire [31:0] EXMA_load_data,
    
    input  wire        MAWB_RegWrite,
    input  wire [4:0]  MAWB_rd,
    input  wire [31:0] MAWB_RF_write_data,

    // hazard detection
    output wire        IDEX_MemRead,
    output wire        IDEX_RegWrite,
    output wire [4:0]  IDEX_rd
);
    // receive from ID and store
    reg [`ID_to_EX_BUS_WIDTH-1:0] ID_to_EX_bus_reg;
    reg                       EX_valid;

    wire EX_ready_go = 1'b1; 

    assign EX_allowin = !EX_valid || (EX_ready_go && MA_allowin);
    assign EX_to_MA_valid = EX_valid && EX_ready_go;

    always @(posedge clk or posedge reset) begin
        if (reset) 
            EX_valid <= 1'b0;
        else begin
            if (EX_allowin) 
                EX_valid <= ID_to_EX_valid;
            if (EX_allowin && ID_to_EX_valid) 
                ID_to_EX_bus_reg <= ID_to_EX_bus;
        end
    end

    wire [31:0] PC_addr;
    wire [31:0] EX_PC_plus_4;
    wire [4:0]  EX_rs1, EX_rs2;
    wire [31:0] RD1, RD2;
    wire [31:0] EX_immout;
    // EX
    wire [3:0]  ALUOp;
    wire ALUSrc1, ALUSrc2;
    //MA
    wire EX_MemWrite;
    wire [2:0]  EX_DMType;
    // WB
    wire [1:0]  EX_MemtoReg;
    wire [4:0]  EX_rd;
    wire EX_RegWrite;
    // CSR
    wire        EX_csr_we;
    wire [11:0] EX_csr_addr;
    wire [31:0] EX_csr_write_data;

    assign {
        PC_addr, 
        EX_PC_plus_4,
        EX_rs1, EX_rs2,
        RD1, RD2, 
        EX_immout,
        ALUOp, ALUSrc1, ALUSrc2,
        EX_MemWrite, EX_DMType,
        EX_MemtoReg, EX_RegWrite, EX_rd,
        EX_csr_we, EX_csr_addr, EX_csr_write_data} = ID_to_EX_bus_reg;

    // hazard detection for load-use
    assign IDEX_MemRead = EX_valid &&(EX_MemtoReg == `MemtoReg_MEM);
    assign IDEX_rd = EX_rd;
    assign IDEX_RegWrite = EX_valid && EX_RegWrite;

    wire [1:0] ForwardA, ForwardB;
    
    forwarding U_forwarding(
        .clk(clk),
        .reset(reset),
        .EX_rs1(EX_rs1),
        .EX_rs2(EX_rs2),
        .EXMA_RegWrite(EXMA_RegWrite), 
        .EXMA_rd(EXMA_rd), 
        .MAWB_RegWrite(MAWB_RegWrite), 
        .MAWB_rd(MAWB_rd), 
        .ForwardA(ForwardA), 
        .ForwardB(ForwardB)  
    );

    wire [31:0] A, B;
    wire [31:0] aluout;

    wire [31:0] forward_RD1, forward_RD2;

    assign forward_RD1 = (ForwardA == `Forward_EXMA)? EXMA_load_data :
                         (ForwardA == `Forward_MAWB)? MAWB_RF_write_data : RD1;

    assign forward_RD2 = (ForwardB == `Forward_EXMA)? EXMA_load_data :
                         (ForwardB == `Forward_MAWB)? MAWB_RF_write_data : RD2;

    assign A = (ALUSrc1 == 1'b0)? forward_RD1 : PC_addr;
    assign B = (ALUSrc2 == 1'b0)? forward_RD2 : EX_immout;

    alu ALU(
        .A(A),
        .B(B),
        .ALUOp(ALUOp),
        .C(aluout)
    );

    assign EX_to_MA_bus = {
        aluout, forward_RD2, // data 32+32=64
        EX_PC_plus_4, // 32
        EX_MemWrite, EX_DMType, // MA 1+3=4
        EX_MemtoReg, EX_RegWrite, EX_rd, // WB 2+1+5=8
        EX_csr_we, EX_csr_addr, EX_csr_write_data}; // CSR 1+12+32=45

endmodule
`endif