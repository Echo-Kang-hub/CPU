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
    output wire [31:0] DM_write_addr,
    output wire [31:0] DM_write_data,
    output wire        DM_write_enable,
    input  wire [31:0] DM_read_data
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

    // MA
    wire [31:0] MA_aluout;
    wire MA_MemWrite;
    // WB
    wire [1:0] MA_WDSel;
    wire MA_RegWrite;
    wire [4:0]  MA_rd;

    assign {
        MA_aluout, DM_write_data, 
        MA_MemWrite, MA_DMType,
        MA_WDSel, MA_RegWrite, MA_rd,
        MA_PC_plus_4} = EX_to_MA_bus_reg;

    // 极其关键：必须是寄存器里有真实有效的指令，且这是一条写内存指令，才能拉高 DM_write_enable
    assign DM_write_enable    = MA_MemWrite && MA_valid; 
    assign DM_write_addr      = MA_aluout;

    // TODO: 这里假设还有一根 MEM_to_RF 信号用来控制 WB 级的多路选择器
    // wire MEM_to_RF;

    assign MA_to_WB_bus = {
        DM_read_data, 
        MA_aluout, 
        MA_WDSel, MA_RegWrite, MA_rd,
        MA_PC_plus_4}; 

endmodule