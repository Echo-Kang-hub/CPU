`ifndef __EX_STAGE_V__   
`define __EX_STAGE_V__
`default_nettype none
`include "definition.vh"

module EX_stage(
    input  wire        clk,
    input  wire        reset,
    input  wire        FLUSH_IDEX, // 处理 Load-Use 冒险时冲刷

    // from ID
    input  wire        ID_to_EX_valid,
    input  wire [`ID_to_EX_BUS_WIDTH-1:0] ID_to_EX_bus,
    output wire        EX_allowin,

    // to MA
    input  wire        MA_allowin,
    output wire        EX_to_MA_valid,
    output wire [`EX_to_MA_BUS_WIDTH-1:0] EX_to_MA_bus
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
        else if (FLUSH_IDEX)
            EX_valid <= 1'b0;
        else begin
            if (EX_allowin) 
                EX_valid <= ID_to_EX_valid;
            if (EX_allowin && ID_to_EX_valid) 
                ID_to_EX_bus_reg <= ID_to_EX_bus;
        end
    end

    wire [31:0] PC_addr;
    wire [31:0] RD1, RD2;
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

    wire [31:0] EX_immout;
    wire [31:0] EX_PC_plus_4;
    

    assign {
        PC_addr, 
        EX_PC_plus_4,
        RD1, RD2, 
        EX_immout,
        ALUOp, ALUSrc1, ALUSrc2,
        EX_MemWrite, EX_DMType,
        EX_MemtoReg, EX_RegWrite, EX_rd} = ID_to_EX_bus_reg;

    wire [31:0] A, B;
    wire [31:0] aluout;
    assign A = (ALUSrc1 == 1'b0)? RD1 : PC_addr;
    assign B = (ALUSrc2 == 1'b0)? RD2 : EX_immout;

    alu ALU(
        .A(A),
        .B(B),
        .ALUOp(ALUOp),
        .C(aluout)
    );

    assign EX_to_MA_bus = {
        aluout, RD2, // data 32+32=64
        EX_PC_plus_4, // 32
        EX_MemWrite, EX_DMType, // MA 1+3=4
        EX_MemtoReg, EX_RegWrite, EX_rd}; // WB 2+1+5=8

endmodule
`endif