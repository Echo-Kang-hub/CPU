`ifndef __FOWARDING_V__
`define __FOWARDING_V__
`default_nettype none
`include "definition.vh"
module forwarding(
    input  wire        clk,
    input  wire        reset,
    
    input  wire [4:0]  EX_rs1,
    input  wire [4:0]  EX_rs2,

    // from EX/MA
    input  wire        EXMA_RegWrite,
    input  wire [4:0]  EXMA_rd,

    // from MA/WB
    input  wire        MAWB_RegWrite,
    input  wire [4:0]  MAWB_rd,

    output wire [1:0]  ForwardA,
    output wire [1:0]  ForwardB
);
    reg [1:0] ForwardA_reg;
    reg [1:0] ForwardB_reg;
    assign {ForwardA, ForwardB} = {ForwardA_reg, ForwardB_reg};

    always @(*) begin 
        ForwardA_reg <= `Forward_NONE;
        ForwardB_reg <= `Forward_NONE;
        
        if (EXMA_RegWrite && (EXMA_rd != 5'b0) && (EXMA_rd == EX_rs1)) 
            ForwardA_reg <= `Forward_EXMA;
        else if (MAWB_RegWrite && (MAWB_rd != 5'b0) && (MAWB_rd == EX_rs1)) 
            ForwardA_reg <= `Forward_MAWB;

        if (EXMA_RegWrite && (EXMA_rd != 5'b0) && (EXMA_rd == EX_rs2)) 
            ForwardB_reg <= `Forward_EXMA;
        else if (MAWB_RegWrite && (MAWB_rd != 5'b0) && (MAWB_rd == EX_rs2)) 
            ForwardB_reg <= `Forward_MAWB;
    end
endmodule
`endif