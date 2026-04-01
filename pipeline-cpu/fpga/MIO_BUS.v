`ifndef __MIO_BUS_V__
`define __MIO_BUS_V__
`timescale 1ns / 1ps

// memory IO bus

module MIO_BUS(
    input wire        clk,
    input wire        rst,
    input wire        mem_w,
    input wire [15:0] sw_i,               // switch input
    input wire [31:0] cpu_data_out,       // data from CPU
    input wire [31:0] cpu_data_addr,      // address for CPU
    input wire [2:0]  cpu_data_amp,       // access pattern from CPU
    input wire [31:0] ram_data_out,       // data from data memory
    
    // Keyboard interface
    input wire [7:0]  key_code,           // keyboard data
    input wire        key_ready,          // key pressed flag
    output reg        key_read,           // CPU read acknowledge
    output wire       key_interrupt,      // keyboard interrupt to CPU
    
    // VGA interface
    output reg  [12:0] vga_addr,          // VGA char memory address
    output reg  [7:0]  vga_write_data,    // VGA char write data
    output reg         vga_we,            // VGA char write enable
    
    output reg  [31:0] cpu_data_in,       // data to CPU
    output reg  [31:0] ram_data_in,       // data to data memory
    output reg  [6:0]  ram_addr,          // address for data memory
    output reg  [31:0] cpuseg7_data,      // cpu seg7 data (from sw instruction)
    output reg         ram_we,            // signal to write data memory
    output reg  [2:0]  ram_amp,           // access pattern for data memory
    output reg         seg7_we            // signal to write seg7 display 
);

    // Keyboard interrupt enable register
    reg key_interrupt_enable;
    reg key_interrupt_we;
    
    // Keyboard interrupt: key_ready AND interrupt enable
    assign key_interrupt = key_ready & key_interrupt_enable;
    
    // RAM & IO decode signals
    always @* begin
        ram_addr = 7'h0;
        ram_data_in = 32'h0;
        cpuseg7_data = 32'h0;
        cpu_data_in = 32'h0;
        seg7_we = 0;
        ram_we = 0;
        ram_amp = 3'b0;
        key_read = 0;
        vga_we = 0;
        vga_addr = 13'h0;
        vga_write_data = 8'h0;
        key_interrupt_we = 0;
        
        case(cpu_data_addr[31:0])
            32'hffff_0004: begin  // switch
                cpu_data_in = {16'h0, sw_i};
            end
            
            32'hffff_000c: begin  // seg7
                cpuseg7_data = cpu_data_out;
                seg7_we = mem_w;
            end
            
            32'hffff_0010: begin  // keyboard data port
                cpu_data_in = {24'h0, key_code};
                key_read = ~mem_w;  // read operation triggers acknowledge
            end
            
            32'hffff_0014: begin  // keyboard status/interrupt enable
                cpu_data_in = {30'h0, key_interrupt_enable, key_ready};
            end
            
            32'hffff_0018: begin  // keyboard interrupt enable write
                key_interrupt_we = mem_w;
            end
            
            32'hffff_0020: begin  // VGA char memory (2400 bytes: 30x80)
                vga_we = mem_w;
                vga_addr = cpu_data_addr[12:0];  // full address
                vga_write_data = cpu_data_out[7:0];
            end
            
            default: begin  // data memory
                ram_addr = cpu_data_addr[8:2];
                ram_data_in = cpu_data_out;
                ram_we = mem_w;
                ram_amp = cpu_data_amp;
                cpu_data_in = ram_data_out;
            end
        endcase
    end
    
    // Keyboard interrupt enable register update
    always @(posedge clk) begin
        if (rst)  // reset
            key_interrupt_enable <= 1'b0;
        else if (key_interrupt_we)
            key_interrupt_enable <= cpu_data_out[0];
    end

endmodule
`endif