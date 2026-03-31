`include "definition.vh"
module csr_regs(
    input wire clk,
    input wire reset,

    // csr signals from MA
    input wire        csr_we,
    input wire [11:0] csr_addr,
    input wire [31:0] csr_write_data,

    // interrupt signals from IF stage
    input wire        interrupt_taken,  // 中断被响应
    input wire [31:0] current_PC,       // 被中断指令的PC
    input wire        mret_taken,       // mret 指令执行
    
    // interrupt signals from MIO_BUS
    input wire ext_interrupt, // external interrupt

    output wire [31:0] mstatus,
    output wire [31:0] mie,
    output wire [31:0] mip,
    output wire [31:0] mepc,
    output wire [31:0] mcause,
    
    // CSR read data output
    output wire [31:0] csr_read_data
);
    // mstatus: [7] MPIE, [3] MIE
    reg [31:0] mstatus_reg;
    assign mstatus = mstatus_reg;

    // mie: [11] MEIE, [7] MTIE, [3] MSIE
    reg [31:0] mie_reg;
    assign mie = mie_reg;

    // mip: [11] MEIP
    reg [31:0] mip_reg;
    assign mip = mip_reg;

    // mepc
    reg [31:0] mepc_reg;
    assign mepc = mepc_reg;

    // mcause
    reg [31:0] mcause_reg;
    assign mcause = mcause_reg;

    // csr write
    always @(posedge clk or posedge reset) begin
        if(reset) begin
            mstatus_reg <= 32'b0;
            mie_reg <= 32'b0;
            mip_reg <= 32'b0;
            mepc_reg <= 32'b0;
            mcause_reg <= 32'b0;
        end
        else begin
            mip_reg[11] <= ext_interrupt;
            
            // Debug
            if (csr_we) $display("CSR_REGS: we=%b addr=0x%h wdata=0x%h int=%b mret=%b", 
                                  csr_we, csr_addr, csr_write_data, interrupt_taken, mret_taken);
            
            // 当中断发生时，自动保存返回地址到mepc，设置原因到mcause
            if(interrupt_taken) begin
                mepc_reg <= current_PC;           // 保存返回地址
                mcause_reg <= 32'h8000000B;       // 外部中断，bit[31]=1表示中断
                mstatus_reg[7] <= mstatus_reg[3]; // MPIE = MIE
                mstatus_reg[3] <= 1'b0;           // MIE = 0 (关全局中断)
            end
            // mret: 恢复 mstatus (MIE=MPIE, MPIE=1)
            else if(mret_taken) begin
                mstatus_reg[3] <= mstatus_reg[7]; // MIE = MPIE
                mstatus_reg[7] <= 1'b1;           // MPIE = 1
            end
            else if(csr_we) begin
                case(csr_addr)
                    12'h300: begin  // CSR_MSTATUS
                        mstatus_reg <= csr_write_data;
                        $display("CSR_REGS: Writing MSTATUS = 0x%h", csr_write_data);
                        if(csr_write_data[3]) begin
                            mstatus_reg[7] <= 1'b1; // 恢复mie同时设mpie
                        end
                    end
                    12'h304: begin
                        mie_reg <= csr_write_data;     // CSR_MIE
                        $display("CSR_REGS: Writing MIE = 0x%h", csr_write_data);
                    end
                    12'h341: mepc_reg <= csr_write_data;    // CSR_MEPC
                    12'h342: mcause_reg <= csr_write_data;  // CSR_MCAUSE
                    default: $display("CSR_REGS: Unknown addr 0x%h", csr_addr);
                endcase
            end
        end
    end

    // CSR read data select
    assign csr_read_data = (csr_addr == 12'h300) ? mstatus :
                           (csr_addr == 12'h304) ? mie :
                           (csr_addr == 12'h344) ? mip :
                           (csr_addr == 12'h341) ? mepc :
                           (csr_addr == 12'h342) ? mcause :
                           32'b0; 

endmodule