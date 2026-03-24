`ifndef __CSR_V__
`define __CSR_V__
`default_nettype none
`include "definition.vh"

module csr(
    input  wire        clk,
    input  wire        reset,
    
    // CSR read interface
    input  wire [11:0] csr_addr,
    output reg  [31:0] csr_rdata,
    
    // CSR write interface
    input  wire        csr_we,
    input  wire [2:0]  csr_op,
    input  wire [31:0] csr_wdata,
    input  wire [4:0]  csr_imm,
    output wire [31:0] csr_result,
    
    // Interrupt interface
    input  wire        external_int,    // External interrupt input
    input  wire        int_taken,       // Interrupt is being taken
    input  wire [31:0] int_pc,          // PC to save on interrupt
    output wire        int_pending,     // Interrupt is pending
    
    // MRET interface
    input  wire        mret_taken,
    output wire [31:0] mepc_out         // PC to restore on MRET
);

    // CSR Registers
    reg [31:0] mstatus;   // Machine status register
    reg [31:0] mie;       // Machine interrupt enable
    reg [31:0] mtvec;     // Machine trap vector
    reg [31:0] mepc;      // Machine exception PC
    reg [31:0] mcause;    // Machine cause
    reg [31:0] mtval;     // Machine trap value
    reg [31:0] mip;       // Machine interrupt pending

    // Write data calculation
    reg [31:0] csr_wdata_eff;
    always @(*) begin
        case(csr_op)
            `CSR_CSRRW:  csr_wdata_eff = csr_wdata;
            `CSR_CSRRS:  csr_wdata_eff = csr_rdata | csr_wdata;
            `CSR_CSRRC:  csr_wdata_eff = csr_rdata & ~csr_wdata;
            `CSR_CSRRWI: csr_wdata_eff = {27'b0, csr_imm};
            `CSR_CSRRSI: csr_wdata_eff = csr_rdata | {27'b0, csr_imm};
            `CSR_CSRRCI: csr_wdata_eff = csr_rdata & ~{27'b0, csr_imm};
            default:     csr_wdata_eff = csr_wdata;
        endcase
    end

    // CSR read
    always @(*) begin
        case(csr_addr)
            `CSR_MSTATUS: csr_rdata = mstatus;
            `CSR_MIE:     csr_rdata = mie;
            `CSR_MTVEC:   csr_rdata = mtvec;
            `CSR_MEPC:    csr_rdata = mepc;
            `CSR_MCAUSE:  csr_rdata = mcause;
            `CSR_MTVAL:   csr_rdata = mtval;
            `CSR_MIP:     csr_rdata = mip;
            default:      csr_rdata = 32'b0;
        endcase
    end

    // CSR result (for instruction write-back)
    assign csr_result = csr_rdata;

    // Interrupt pending logic
    wire mie_bit = mstatus[3];     // MIE bit
    wire meie_bit = mie[11];       // MEIE bit (Machine External Interrupt Enable)
    assign int_pending = mie_bit & meie_bit & mip[11];

    // MEPC output for MRET
    assign mepc_out = mepc;

    // MIP update (external interrupt pending)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mip <= 32'b0;
        end else begin
            mip[11] <= external_int;  // MEIP bit
        end
    end

    // CSR write logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mstatus <= 32'h00001800;  // MPP = 11 (Machine mode)
            mie     <= 32'b0;
            mtvec   <= 32'b0;
            mepc    <= 32'b0;
            mcause  <= 32'b0;
            mtval   <= 32'b0;
        end else begin
            // Priority: Interrupt > MRET > CSR instruction
            
            if (int_taken) begin
                // Save current PC
                mepc <= int_pc;
                // Set cause (machine external interrupt)
                mcause <= `MCAUSE_MACHINE_EXTERNAL_INT;
                // Save MIE to MPIE, clear MIE
                mstatus[7] <= mstatus[3];  // MPIE = MIE
                mstatus[3] <= 1'b0;        // MIE = 0
                mstatus[12:11] <= 2'b11;   // MPP = Machine mode
            end else if (mret_taken) begin
                // Restore MIE from MPIE
                mstatus[3] <= mstatus[7];  // MIE = MPIE
                mstatus[7] <= 1'b1;        // MPIE = 1
            end else if (csr_we) begin
                // CSR instruction write
                case(csr_addr)
                    `CSR_MSTATUS: mstatus <= csr_wdata_eff;
                    `CSR_MIE:     mie <= csr_wdata_eff;
                    `CSR_MTVEC:   mtvec <= csr_wdata_eff;
                    `CSR_MEPC:    mepc <= csr_wdata_eff;
                    `CSR_MCAUSE:  mcause <= csr_wdata_eff;
                    `CSR_MTVAL:   mtval <= csr_wdata_eff;
                    default: ; // Read-only or non-existent CSR
                endcase
            end
        end
    end

endmodule
`endif
