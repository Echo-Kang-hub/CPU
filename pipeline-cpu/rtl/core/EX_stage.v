`include "definition.vh"

module EX_stage(
    input  wire        clk,
    input  wire        reset,
    input  wire        FLUSH_IDEX, // 处理 Load-Use 冒险时冲刷本级

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

    always @(posedge clk or posedge reset or posedge FLUSH_IDEX) begin
        if (reset || FLUSH_IDEX) 
            EX_valid <= 1'b0;
        else begin
            if (EX_allowin) 
                EX_valid <= ID_to_EX_valid;
            if (EX_allowin && ID_to_EX_valid) 
                ID_to_EX_bus_reg <= ID_to_EX_bus;
        end
    end


    wire [31:0] PC_addr, RD1, RD2, immout;
    wire [3:0]  ALUOp, EX_rd;
    wire        EX_RegWrite, EX_MemWrite;
    assign {PC_addr, RD1, RD2, ALUOp, ALUSrc, EX_rd, EX_RegWrite, EX_MemWrite} = ID_to_EX_bus_reg;

    wire [31:0] A, B;
    wire [31:0] aluout;
    assign B = (ALUSrc == 1'b0)? RD2 : immout;

    alu ALU(
        .A(RD1),
        .B(B),
        .ALUOp(ALUOp),
        .C(aluout)
    );

    assign EX_to_MA_bus = {aluout, B, EX_rd, EX_RegWrite, EX_MemWrite};

endmodule