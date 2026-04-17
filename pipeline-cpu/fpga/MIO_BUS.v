`ifndef __MIO_BUS_V__
`define __MIO_BUS_V__
`timescale 1ns / 1ps

// memory IO bus

module MIO_BUS(
    input wire        clk,
    input wire        reset,
    input wire [15:0] sw_i, 

    // from CPU
    input wire        bus_write_enable,
    input wire        bus_read_enable,
    input wire [31:0] bus_write_data,
    input wire [31:0] bus_write_addr,
    input wire [2:0]  bus_DM_Type,
    
    // from DM
    input wire [31:0] DM_read_data, 

    // Keyboard interface
    input wire [7:0]  key_code,
    input wire        key_ready, 
    output wire       key_read_acknowledge, 
    output wire       key_interrupt, 
    
    // VGA interface
    output reg         vga_write_enable, 
    output reg  [12:0] vga_write_addr, 
    output reg  [7:0]  vga_write_data, 
    output reg  [12:0] vga_read_addr,
    input  wire [7:0]  vga_read_data,
    
    // to CPU
    output reg  [31:0] bus_read_data,
    // to DM
    output reg         DM_write_enable, 
    output reg  [31:0] DM_write_addr,
    output reg  [31:0] DM_write_data,
    output reg  [2:0]  DM_Type,
    // to SEG7x16
    output reg  [31:0] cpuseg7_data,  
    output reg         seg7_write_enable 
);

    // MMIO map: 0xFFFF_0000 + offset
    localparam [31:0] IO_BASE               = 32'hffff_0000;
    localparam [31:0] SWITCH_ADDR           = IO_BASE + 32'h0004;
    localparam [31:0] SEG7_ADDR             = IO_BASE + 32'h000c;
    localparam [31:0] KBD_DATA_ADDR         = IO_BASE + 32'h0010;
    localparam [31:0] KBD_STATUS_ADDR       = IO_BASE + 32'h0014;
    localparam [31:0] KBD_INT_EN_ADDR       = IO_BASE + 32'h0018;
    localparam [31:0] VGA_BASE_ADDR         = IO_BASE + 32'h0020;
    localparam [12:0] VGA_CHAR_COUNT        = 13'd2400;
    localparam [31:0] VGA_WINDOW_SIZE_BYTES = 32'd9600;
    localparam [31:0] VGA_END_ADDR_EXCL     = VGA_BASE_ADDR + VGA_WINDOW_SIZE_BYTES;

    wire is_kbd_data_read = bus_read_enable && (bus_write_addr == KBD_DATA_ADDR);
    wire is_vga_window = (bus_write_addr >= VGA_BASE_ADDR) && (bus_write_addr < VGA_END_ADDR_EXCL);
    wire is_vga_word_aligned = (bus_write_addr[1:0] == 2'b00);
    wire [12:0] vga_word_index = (bus_write_addr - VGA_BASE_ADDR) >> 2;

    // Keyboard interrupt enable register
    reg key_interrupt_enable;
    reg key_interrupt_write_enable;
    
    // Keyboard interrupt
    assign key_interrupt = key_ready & key_interrupt_enable;
    



    // Keyboard read acknowledgment
    reg key_read_acknowledge_reg;
    reg is_kbd_data_read_d1;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            is_kbd_data_read_d1 <= 1'b0;
        end
        else begin
            is_kbd_data_read_d1 <= is_kbd_data_read;
        end
    end

    wire kbd_read_pulse;
    // key_ready在此是跨时钟的，而且ps2_keyboard模块已经考虑key_ready，这里不用引入key_ready
    assign kbd_read_pulse = is_kbd_data_read && (!is_kbd_data_read_d1);
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            key_read_acknowledge_reg <= 1'b0;
        end
        else begin
            key_read_acknowledge_reg <= kbd_read_pulse;
        end
    end

    assign key_read_acknowledge = key_read_acknowledge_reg;
    




    // RAM & IO decode signals
    always @(*) begin
        // to DM
        DM_write_addr = 32'h0;
        DM_write_data = 32'h0;
        DM_write_enable = 0;
        DM_Type = 3'b0;
        // to SEG7x16
        seg7_write_enable = 0;
        cpuseg7_data = 32'h0;
        // to CPU
        bus_read_data = 32'h0;
        // to VGA
        vga_write_enable = 0;
        vga_write_addr = 13'h0;
        vga_write_data = 8'h0;
        vga_read_addr = 13'h0;
        
        key_interrupt_write_enable = 0;
        
        case(bus_write_addr[31:0])
            SWITCH_ADDR: begin  // switch
                bus_read_data = {16'h0, sw_i};
            end
            
            SEG7_ADDR: begin  // seg7
                cpuseg7_data = bus_write_data;
                seg7_write_enable = bus_write_enable;
            end
            
            KBD_DATA_ADDR: begin  // keyboard data port
                bus_read_data = {24'h0, key_code};
            end
            
            KBD_STATUS_ADDR: begin  // keyboard status/interrupt enable
                bus_read_data = {30'h0, key_interrupt_enable, key_ready};
            end
            
            KBD_INT_EN_ADDR: begin  // keyboard interrupt enable write
                key_interrupt_write_enable = bus_write_enable;
            end
            
            default: begin
                // VGA char memory window (word-addressed)
                if (is_vga_window) begin
                    vga_write_enable = bus_write_enable && is_vga_word_aligned && (vga_word_index < VGA_CHAR_COUNT);
                    vga_write_addr = vga_word_index;
                    vga_write_data = bus_write_data[7:0];
                    vga_read_addr = vga_word_index;
                    if (bus_read_enable && is_vga_word_aligned && (vga_word_index < VGA_CHAR_COUNT))
                        bus_read_data = {24'h0, vga_read_data};
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