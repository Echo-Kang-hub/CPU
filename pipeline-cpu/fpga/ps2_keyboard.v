`ifndef __PS2_KEYBOARD_V__
`define __PS2_KEYBOARD_V__
`timescale 1ns / 1ps

module ps2_keyboard(
    input  wire clk,
    input  wire reset,
    input  wire ps2_clk,
    input  wire ps2_data,
    
    output reg  [7:0] key_code,
    output reg        key_ready,
    input  wire       key_read_ack
);
    // PS/2 clock edge detection
    reg [2:0] ps2_clk_sync;
    wire ps2_clk_fall = ps2_clk_sync[2] & ~ps2_clk_sync[1];
    
    // Receive shift register
    reg [10:0] shift_reg;
    reg [3:0] bit_cnt;
    
    // Break code detection
    reg break_detected;
    
    always @(posedge clk) begin
        ps2_clk_sync <= {ps2_clk_sync[1:0], ps2_clk};
        
        if (reset) begin
            bit_cnt <= 4'd0;
            key_ready <= 1'b0;
            break_detected <= 1'b0;
        end
        else begin
            // Handle key read acknowledgment
            if (key_ready && key_read_ack) begin
                key_ready <= 1'b0;
            end
            
            // Receive data
            if (ps2_clk_fall) begin
                case(bit_cnt)
                    4'd0: bit_cnt <= bit_cnt + 1;  // start bit
                    4'd1, 4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd7, 4'd8: begin
                        shift_reg[bit_cnt - 1] <= ps2_data;
                        bit_cnt <= bit_cnt + 1;
                    end
                    4'd9: bit_cnt <= bit_cnt + 1;  // parity bit
                    4'd10: begin  // stop bit
                        if (ps2_data && ^shift_reg[9:1]) begin
                            // Check for break code (F0)
                            if (shift_reg[8:1] == 8'hF0) begin
                                break_detected <= 1'b1;
                            end
                            else if (break_detected) begin
                                // Key release, ignore
                                break_detected <= 1'b0;
                            end
                            else begin
                                // Key press
                                key_code <= shift_reg[8:1];
                                key_ready <= 1'b1;
                                break_detected <= 1'b0;
                            end
                        end
                        bit_cnt <= 4'd0;
                    end
                endcase
            end
        end
    end

endmodule
`endif