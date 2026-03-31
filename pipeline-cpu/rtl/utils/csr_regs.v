`include "definition.vh"

module csr_regs(
    input wire clk,
    input wire reset,

    // interrupt signals from MIO_BUS
    input wire ext_interrupt, 

    // csr signals from MA
    input wire        csr_we,
    input wire [11:0] csr_addr,
    input wire [31:0] csr_write_data,

    // interrupt signals from IF stage
    input wire        interrupt_taken,  // 中断被响应
    input wire [31:0] current_PC,       // 被中断指令的PC
    input wire        mret_taken, 

    output wire [31:0] mtvec,
    output wire [31:0] mie,
    output wire [31:0] mip,
    output wire [31:0] mstatus,
    output wire [31:0] mcause,
    output wire [31:0] mepc,
    
    // CSR read data output
    output wire [31:0] csr_read_data
);
    // mtvec
    reg [31:0] mtvec_reg;
    assign mtvec = mtvec_reg;

    // mie: [`MIE_MEIE] MEIE, [`MIE_MTIE] MTIE, [`MIE_MSIE] MSIE
    reg [31:0] mie_reg;
    assign mie = mie_reg;

    // mip: [`MIP_MEIP] MEIP
    reg [31:0] mip_reg;
    assign mip = mip_reg;

    // mstatus: [`MSTATUS_MPIE] MPIE, [`MSTATUS_MIE] MIE
    reg [31:0] mstatus_reg;
    assign mstatus = mstatus_reg;
    
    // mcause
    reg [31:0] mcause_reg;
    assign mcause = mcause_reg;

    // mepc
    reg [31:0] mepc_reg;
    assign mepc = mepc_reg;


    // csr write
    always @(posedge clk or posedge reset) begin
        if(reset) begin
            mstatus_reg <= 32'b0;
            mie_reg <= 32'b0;
            mip_reg <= 32'b0;
            mtvec_reg <= `MTVEC_BASE;
            mepc_reg <= 32'b0;
            mcause_reg <= 32'b0;
        end
        else begin
            mip_reg[`MIP_MEIP] <= ext_interrupt;
            
            // 当中断发生时，自动保存返回地址到mepc，设置原因到mcause
            if(interrupt_taken) begin
                mepc_reg <= current_PC; 
                mcause_reg <= {1'b1, 31'd`CAUSE_EXTERNAL}; // 外部中断，bit[31]=1表示中断
                mstatus_reg[`MSTATUS_MPIE] <= mstatus_reg[`MSTATUS_MIE]; // MPIE = MIE
                mstatus_reg[`MSTATUS_MIE] <= 1'b0;                       // MIE = 0 (关全局中断)
            end
            // mret: 恢复 mstatus (MIE=MPIE, MPIE=1)
            else if(mret_taken) begin
                mstatus_reg[`MSTATUS_MIE] <= mstatus_reg[`MSTATUS_MPIE]; // MIE = MPIE
                mstatus_reg[`MSTATUS_MPIE] <= 1'b1;                      // MPIE = 1
            end
            else if(csr_we) begin
                case(csr_addr)
                    `CSR_MSTATUS: begin
                        mstatus_reg <= csr_write_data;
                        if(csr_write_data[`MSTATUS_MIE]) begin
                            mstatus_reg[`MSTATUS_MPIE] <= 1'b1; // 恢复mie同时设mpie
                        end
                    end
                    `CSR_MTVEC:   mtvec_reg <= csr_write_data;
                    `CSR_MIE:     mie_reg <= csr_write_data;
                    `CSR_MEPC:    mepc_reg <= csr_write_data;
                    `CSR_MCAUSE:  mcause_reg <= csr_write_data;
                    default: ; // 忽略未知地址
                endcase
            end
        end
    end

    // CSR read data select
                           
    assign csr_read_data = (csr_addr == `CSR_MTVEC)   ? mtvec :
                           (csr_addr == `CSR_MIE)     ? mie :
                           (csr_addr == `CSR_MIP)     ? mip :
                           (csr_addr == `CSR_MSTATUS) ? mstatus :
                           (csr_addr == `CSR_MCAUSE)  ? mcause :
                           (csr_addr == `CSR_MEPC)    ? mepc :
                           (csr_addr == `MRET_FUNCT)  ? mepc :  // mret needs mepc
                           32'b0; 

endmodule
