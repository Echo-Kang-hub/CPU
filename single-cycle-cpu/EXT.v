`include "definition.vh"
module EXT(
    input [4:0] iimm_shamt,
    input [11:0] iimm,
    input [11:0] simm,
    input [11:0] bimm,
    input [19:0] uimm,
    input [19:0] jimm,
    input [2:0] EXTOp,
    output reg [31:0] immout
);
    always @(*) begin
        case (EXTOp)
            `EXT_SHAMT: immout <= {27'b0,iimm_shamt[4:0]}; // I-type 立即数 (用于 slli/srli/srai)
            `EXT_ITYPE: immout <= {{20{iimm[11]}}, iimm[11:0]}; // I-type 立即数 (用于 addi, lw, jalr 等)
            `EXT_STYPE: immout <= {{20{simm[11]}}, simm[11:0]}; // S-type 立即数 (用于 sw 等)
            `EXT_BTYPE: immout<= {{19{bimm[11]}},bimm[11:0],1'b0}; // B-type 立即数 (用于 beq 等)
            `EXT_UTYPE: immout <= {uimm[19:0], 12'b0}; // U-type 立即数 (用于 lui, auipc)
            `EXT_JTYPE: immout<= {{11{jimm[19]}},jimm[19:0],1'b0}; // J-type 立即数 (用于 jal)
            default: immout <= 32'b0;
        endcase
    end

endmodule