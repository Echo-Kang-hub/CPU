`ifndef __PS2_CTRL_V__
`define __PS2_CTRL_V__
`default_nettype none

module ps2_ctrl(
    input  wire        clk,           // System clock (50MHz)
    input  wire        reset,         // Reset
    
    // PS/2 interface
    input  wire        ps2_clk,       // PS/2 clock
    input  wire        ps2_data,      // PS/2 data
    
    // CPU interface (memory mapped I/O)
    input  wire [31:0] addr,          // Address
    input  wire        rd_en,         // Read enable
    output reg  [31:0] rdata,         // Read data
    
    // Interrupt output
    output wire        int_out        // Interrupt output (active high)
);

    // Memory map:
    // 0xFFFF0000: Status register (bit 0: data ready)
    // 0xFFFF0004: Data register (bits [7:0]: ASCII code)

    // Synchronize PS/2 clock and data (2-stage synchronizer)
    reg ps2_clk_sync1, ps2_clk_sync2;
    reg ps2_data_sync1, ps2_data_sync2;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ps2_clk_sync1 <= 1'b1;
            ps2_clk_sync2 <= 1'b1;
            ps2_data_sync1 <= 1'b1;
            ps2_data_sync2 <= 1'b1;
        end else begin
            ps2_clk_sync1 <= ps2_clk;
            ps2_clk_sync2 <= ps2_clk_sync1;
            ps2_data_sync1 <= ps2_data;
            ps2_data_sync2 <= ps2_data_sync1;
        end
    end
    
    // Detect falling edge of PS/2 clock
    reg ps2_clk_prev;
    wire ps2_clk_falling = ps2_clk_prev & ~ps2_clk_sync2;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ps2_clk_prev <= 1'b1;
        end else begin
            ps2_clk_prev <= ps2_clk_sync2;
        end
    end
    
    // PS/2 receiver state machine
    reg [3:0] bit_cnt;
    reg [7:0] shift_reg;
    reg [7:0] scan_code;
    reg       scan_ready;
    reg       receiving;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            bit_cnt <= 4'd0;
            shift_reg <= 8'd0;
            scan_code <= 8'd0;
            scan_ready <= 1'b0;
            receiving <= 1'b0;
        end else begin
            scan_ready <= 1'b0;  // Default: clear ready flag
            
            if (ps2_clk_falling) begin
                if (!receiving) begin
                    // Wait for start bit (low)
                    if (!ps2_data_sync2) begin
                        receiving <= 1'b1;
                        bit_cnt <= 4'd0;
                    end
                end else begin
                    if (bit_cnt < 4'd8) begin
                        // Data bits (LSB first)
                        shift_reg[bit_cnt] <= ps2_data_sync2;
                        bit_cnt <= bit_cnt + 4'd1;
                    end else if (bit_cnt == 4'd8) begin
                        // Parity bit (ignore for now)
                        bit_cnt <= bit_cnt + 4'd1;
                    end else begin
                        // Stop bit
                        receiving <= 1'b0;
                        scan_code <= shift_reg;
                        scan_ready <= 1'b1;
                    end
                end
            end
        end
    end
    
    // Scan code to ASCII conversion
    reg [7:0] ascii_code;
    reg       key_valid;
    reg       break_code;  // Track break code (0xF0)
    reg       extended;    // Track extended code (0xE0)
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ascii_code <= 8'd0;
            key_valid <= 1'b0;
            break_code <= 1'b0;
            extended <= 1'b0;
        end else if (scan_ready) begin
            if (scan_code == 8'hF0) begin
                // Break code received
                break_code <= 1'b1;
            end else if (scan_code == 8'hE0) begin
                // Extended code received
                extended <= 1'b1;
            end else begin
                // Regular scan code
                if (!break_code) begin
                    // Make code - convert to ASCII
                    ascii_code <= scan_to_ascii(scan_code);
                    key_valid <= 1'b1;
                end else begin
                    // Break code - clear key
                    key_valid <= 1'b0;
                end
                break_code <= 1'b0;
                extended <= 1'b0;
            end
        end
    end
    
    // ASCII buffer
    reg [7:0] ascii_buffer;
    reg       data_ready;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ascii_buffer <= 8'd0;
            data_ready <= 1'b0;
        end else if (key_valid && !data_ready) begin
            ascii_buffer <= ascii_code;
            data_ready <= 1'b1;
        end else if (rd_en && addr[2]) begin
            // Clear data ready when data register is read
            data_ready <= 1'b0;
        end
    end
    
    // Interrupt output
    assign int_out = data_ready;
    
    // Memory mapped read
    always @(*) begin
        case (addr[3:2])
            2'b00: rdata = {31'b0, data_ready};  // Status register
            2'b01: rdata = {24'b0, ascii_buffer}; // Data register
            default: rdata = 32'b0;
        endcase
    end
    
    // Scan code to ASCII lookup function
    function [7:0] scan_to_ascii;
        input [7:0] scan;
        begin
            case (scan)
                // Numbers
                8'h16: scan_to_ascii = 8'h31; // 1
                8'h1E: scan_to_ascii = 8'h32; // 2
                8'h26: scan_to_ascii = 8'h33; // 3
                8'h25: scan_to_ascii = 8'h34; // 4
                8'h2E: scan_to_ascii = 8'h35; // 5
                8'h36: scan_to_ascii = 8'h36; // 6
                8'h3D: scan_to_ascii = 8'h37; // 7
                8'h3E: scan_to_ascii = 8'h38; // 8
                8'h46: scan_to_ascii = 8'h39; // 9
                8'h45: scan_to_ascii = 8'h30; // 0
                
                // Letters
                8'h1C: scan_to_ascii = 8'h61; // a
                8'h32: scan_to_ascii = 8'h62; // b
                8'h21: scan_to_ascii = 8'h63; // c
                8'h23: scan_to_ascii = 8'h64; // d
                8'h24: scan_to_ascii = 8'h65; // e
                8'h2B: scan_to_ascii = 8'h66; // f
                8'h34: scan_to_ascii = 8'h67; // g
                8'h33: scan_to_ascii = 8'h68; // h
                8'h43: scan_to_ascii = 8'h69; // i
                8'h3B: scan_to_ascii = 8'h6A; // j
                8'h42: scan_to_ascii = 8'h6B; // k
                8'h4B: scan_to_ascii = 8'h6C; // l
                8'h3A: scan_to_ascii = 8'h6D; // m
                8'h31: scan_to_ascii = 8'h6E; // n
                8'h44: scan_to_ascii = 8'h6F; // o
                8'h4D: scan_to_ascii = 8'h70; // p
                8'h15: scan_to_ascii = 8'h71; // q
                8'h2D: scan_to_ascii = 8'h72; // r
                8'h1B: scan_to_ascii = 8'h73; // s
                8'h2C: scan_to_ascii = 8'h74; // t
                8'h3C: scan_to_ascii = 8'h75; // u
                8'h2A: scan_to_ascii = 8'h76; // v
                8'h1D: scan_to_ascii = 8'h77; // w
                8'h22: scan_to_ascii = 8'h78; // x
                8'h35: scan_to_ascii = 8'h79; // y
                8'h1A: scan_to_ascii = 8'h7A; // z
                
                // Special keys
                8'h29: scan_to_ascii = 8'h20; // Space
                8'h5A: scan_to_ascii = 8'h0D; // Enter (CR)
                8'h66: scan_to_ascii = 8'h08; // Backspace
                8'h0D: scan_to_ascii = 8'h09; // Tab
                
                default: scan_to_ascii = 8'h00; // Unknown
            endcase
        end
    endfunction

endmodule
`endif
