`ifndef __MA_STAGE_V__  
`define __MA_STAGE_V__
`default_nettype none
`include "definition.vh"

module MA_stage(
    input  wire        clk,
    input  wire        reset,

    // from EX
    input  wire        EX_to_MA_valid,
    input  wire [`EX_to_MA_BUS_WIDTH-1:0] EX_to_MA_bus,
    output wire        MA_allowin,

    // to WB
    input  wire        WB_allowin,
    output wire        MA_to_WB_valid,
    output wire [`MA_to_WB_BUS_WIDTH-1:0] MA_to_WB_bus,

    // DM
    output wire        DM_write_enable,
    output wire [2:0]  DMType,
    output wire [31:0] DM_write_addr,
    output wire [31:0] DM_write_data,
    input  wire [31:0] DM_read_data,

    // I/O interface
    input  wire [31:0] io_rdata,
    output wire        io_rd_en,
    output wire        io_wr_en,
    output wire [31:0] io_addr,

    output wire        EXMA_RegWrite,
    output wire [4:0]  EXMA_rd,
    output wire [31:0] EXMA_aluout,

    output wire        EXMA_MemRead
);
    // receive from EX and store
    reg [`EX_to_MA_BUS_WIDTH-1:0] EX_to_MA_bus_reg;
    reg                           MA_valid;

    wire MA_ready_go = 1'b1;
    assign MA_allowin = !MA_valid || (MA_ready_go && WB_allowin);
    assign MA_to_WB_valid = MA_valid && MA_ready_go;

    always @(posedge clk or posedge reset) begin
        if (reset)
            MA_valid <= 1'b0;
        else begin
            if (MA_allowin)
                MA_valid <= EX_to_MA_valid;
            if (MA_allowin && EX_to_MA_valid)
                EX_to_MA_bus_reg <= EX_to_MA_bus;
        end
    end

    wire [31:0] MA_PC_plus_4;
    // MA
    wire [31:0] MA_aluout;
    wire MA_MemWrite;
    wire [2:0]  MA_DMType;
    // WB
    wire [1:0] MA_MemtoReg;
    wire MA_RegWrite;
    wire [4:0]  MA_rd;
    // CSR
    wire [2:0]  MA_CSROp;
    wire [11:0] MA_CSR_addr;
    wire [31:0] MA_CSR_wdata;
    wire        MA_is_csr;

    assign {
        MA_aluout, DM_write_data,
        MA_PC_plus_4,
        MA_MemWrite, MA_DMType,
        MA_MemtoReg, MA_RegWrite, MA_rd,
        MA_CSROp, MA_CSR_addr, MA_CSR_wdata, MA_is_csr} = EX_to_MA_bus_reg;

    // Memory mapped I/O address decoding
    wire is_io_addr = (MA_aluout[31:16] == 16'hFFFF);  // 0xFFFF0000 - 0xFFFF00FF
    wire is_io_read = is_io_addr && MA_valid && (MA_MemtoReg == `MemtoReg_MEM);
    wire is_io_write = is_io_addr && MA_valid && MA_MemWrite;

    assign io_rd_en = is_io_read;
    assign io_wr_en = is_io_write;
    assign io_addr = MA_aluout;

    assign DMType = MA_DMType;
    assign DM_write_enable = MA_MemWrite && MA_valid && !is_io_addr;
    assign DM_write_addr = MA_aluout;

    // Mux between DM and I/O for read data
    wire [31:0] mem_read_data = is_io_addr ? io_rdata : DM_read_data;

    // forwarding
    assign EXMA_RegWrite = MA_valid && MA_RegWrite;
    assign EXMA_rd = MA_rd;
    assign EXMA_aluout = MA_aluout;

    // hazard detection
    assign EXMA_MemRead = MA_valid && (MA_MemtoReg == `MemtoReg_MEM);

    assign MA_to_WB_bus = {
        MA_aluout, // 32
        mem_read_data,  // 32 (from DM or I/O)
        MA_PC_plus_4, // 32
        MA_MemtoReg, MA_RegWrite, MA_rd,  // 2 + 1 + 5 = 8
        MA_CSROp, MA_CSR_addr, MA_CSR_wdata, MA_is_csr};  // CSR 3+12+32+1=48

endmodule
`endif