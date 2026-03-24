`ifndef __INTERRUPT_CTRL_V__
`define __INTERRUPT_CTRL_V__
`default_nettype none
`include "definition.vh"

module interrupt_ctrl(
    input  wire        clk,
    input  wire        reset,
    
    // Interrupt sources
    input  wire        external_int,    // External interrupt (keyboard)
    
    // CSR interface
    input  wire        mstatus_mie,     // Global interrupt enable from mstatus
    input  wire        mie_meie,        // Machine external interrupt enable from mie
    output wire        mip_meip,        // Machine external interrupt pending to mip
    
    // Pipeline control
    input  wire        int_taken,       // Interrupt is being taken (from pipeline)
    output wire        int_pending,     // Interrupt is pending and should be taken
    
    // Pipeline flush signals
    input  wire        branch_taken,
    input  wire        jal_taken,
    input  wire        jalr_taken,
    input  wire        stall,
    
    // Current instruction in ID stage
    input  wire        id_valid,
    input  wire [31:0] id_pc,
    input  wire        id_is_mret,      // Is MRET instruction in ID stage
    
    // Output to pipeline
    output wire        flush_ifid,
    output wire        flush_idex,
    output wire        int_taken_out,
    output wire [31:0] int_pc_out       // PC to save when interrupt is taken
);

    // Synchronize external interrupt (2-stage synchronizer to avoid metastability)
    reg ext_int_sync1, ext_int_sync2;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ext_int_sync1 <= 1'b0;
            ext_int_sync2 <= 1'b0;
        end else begin
            ext_int_sync1 <= external_int;
            ext_int_sync2 <= ext_int_sync1;
        end
    end
    
    // Edge detection for external interrupt
    reg ext_int_prev;
    wire ext_int_edge = ext_int_sync2 & ~ext_int_prev;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ext_int_prev <= 1'b0;
        end else begin
            ext_int_prev <= ext_int_sync2;
        end
    end
    
    // Latch external interrupt pending
    reg ext_int_pending;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ext_int_pending <= 1'b0;
        end else if (ext_int_edge) begin
            ext_int_pending <= 1'b1;
        end else if (int_taken) begin
            ext_int_pending <= 1'b0;  // Clear when interrupt is taken
        end
    end
    
    // MIP output
    assign mip_meip = ext_int_pending;
    
    // Interrupt pending logic
    // Interrupt can be taken when:
    // 1. Global interrupt enable (MIE) is set
    // 2. External interrupt enable (MEIE) is set
    // 3. External interrupt is pending
    // 4. Pipeline is not stalled
    // 5. Not currently taking an interrupt
    // 6. Not in the middle of a branch/jump (ensure atomicity)
    wire int_condition = mstatus_mie & mie_meie & ext_int_pending;
    wire pipeline_ready = ~stall & ~branch_taken & ~jal_taken & ~jalr_taken;
    
    assign int_pending = int_condition & pipeline_ready & ~int_taken;
    
    // Interrupt take logic
    reg int_taken_reg;
    reg [31:0] int_pc_reg;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            int_taken_reg <= 1'b0;
            int_pc_reg <= 32'b0;
        end else if (int_pending & id_valid & ~id_is_mret) begin
            // Take interrupt on valid instruction
            int_taken_reg <= 1'b1;
            int_pc_reg <= id_pc;
        end else begin
            int_taken_reg <= 1'b0;
        end
    end
    
    assign int_taken_out = int_taken_reg;
    assign int_pc_out = int_pc_reg;
    
    // Pipeline flush when interrupt is taken
    assign flush_ifid = int_taken_reg;
    assign flush_idex = int_taken_reg;

endmodule
`endif
