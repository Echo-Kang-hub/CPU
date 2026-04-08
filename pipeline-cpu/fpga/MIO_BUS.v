`ifndef __MIO_BUS_V__
`define __MIO_BUS_V__
`timescale 1ns / 1ps

// memory IO bus

module MIO_BUS(
    input wire        clk,
    input wire        reset,
    input wire [15:0] sw_i,               // switch input

    // from CPU
    input wire        bus_write_enable,
    input wire [31:0] bus_write_data,       // data from CPU
    input wire [31:0] bus_write_addr,      // address for CPU
    input wire [2:0]  bus_DM_Type,          // access pattern from CPU
    
    // from DM
    input wire [31:0] DM_read_data,       // data from data memory

    // Keyboard interface
    input wire [7:0]  key_code,           // keyboard data
    input wire        key_ready,          // key pressed flag
    output wire       key_read,           // CPU read acknowledge
    output wire       key_interrupt,      // keyboard interrupt to CPU
    
    // VGA interface
    output reg  [12:0] vga_addr,          // VGA char memory address
    output reg  [7:0]  vga_write_data,    // VGA char write data
    output reg         vga_write_enable,            // VGA char write enable
    
    // to CPU
    output reg  [31:0] bus_read_data,       // data to CPU
    // to DM
    output reg         DM_write_enable,      // signal to write data memory
    output reg  [31:0] DM_write_addr,        // byte address for data memory
    output reg  [31:0] DM_write_data,        // data to data memory
    output reg  [2:0]  DM_Type,              // access pattern for data memory
    // to SEG7x16
    output reg  [31:0] cpuseg7_data,        // cpu seg7 data (from sw instruction)
    output reg         seg7_write_enable    // signal to write seg7 display
);

    // Keyboard interrupt enable register
    reg key_interrupt_enable;
    reg key_interrupt_write_enable;
    
    // Keyboard interrupt: key_ready AND interrupt enable
    assign key_interrupt = key_ready & key_interrupt_enable;
    
    // Keyboard read acknowledgment - use sequential logic to generate falling edge
    // This allows ps2_keyboard to reliably detect CPU reading the keyboard
    reg key_read_reg;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            key_read_reg <= 1;
        end
        else begin
            if (!bus_write_enable && (bus_write_addr[31:0] == 32'hffff_0010)) begin
                key_read_reg <= 0;   // CPU accesses keyboard port, pull low
            end
            else begin
                key_read_reg <= 1;   // Otherwise keep high
            end
        end
    end
    assign key_read = key_read_reg;
    
    // RAM & IO decode signals
    always @* begin
        DM_write_addr = 32'h0;
        DM_write_data = 32'h0;
        cpuseg7_data = 32'h0;
        bus_read_data = 32'h0;
        seg7_write_enable = 0;
        DM_write_enable = 0;
        DM_Type = 3'b0;
        vga_write_enable = 0;
        vga_addr = 13'h0;
        vga_write_data = 8'h0;
        key_interrupt_write_enable = 0;
        
        case(bus_write_addr[31:0])
            32'hffff_0004: begin  // switch
                bus_read_data = {16'h0, sw_i};
            end
            
            32'hffff_000c: begin  // seg7
                cpuseg7_data = bus_write_data;
                seg7_write_enable = bus_write_enable;
            end
            
            32'hffff_0010: begin  // keyboard data port
                bus_read_data = {24'h0, key_code};
            end
            
            32'hffff_0014: begin  // keyboard status/interrupt enable
                bus_read_data = {30'h0, key_interrupt_enable, key_ready};
            end
            
            32'hffff_0018: begin  // keyboard interrupt enable write
                key_interrupt_write_enable = bus_write_enable;
            end
            
            default: begin
                // VGA char memory window: 0xFFFF0020 ~ 0xFFFF097F (2400 bytes)
                if ((bus_write_addr >= 32'hffff_0020) && (bus_write_addr < 32'hffff_0980)) begin
                    // VGA text window is write-only from CPU side.
                    // Read from this range returns zero for deterministic behavior.
                    vga_write_enable = bus_write_enable;
                    vga_addr = bus_write_addr[12:0] - 13'h020;
                    vga_write_data = bus_write_data[7:0];
                    if (!bus_write_enable)
                        bus_read_data = 32'h0000_0000;
                end else begin
                    DM_write_enable = bus_write_enable;
                    DM_write_addr = bus_write_addr;
                    DM_write_data = bus_write_data;
                    DM_Type = bus_DM_Type;
                    bus_read_data = DM_read_data;
                end
            end
        endcase
    end
    
    // Keyboard interrupt enable register update
    always @(posedge clk or posedge reset) begin
        if (reset)  // reset
            key_interrupt_enable <= 1'b0;
        else if (key_interrupt_write_enable)
            key_interrupt_enable <= bus_write_data[0];
    end

endmodule
`endif