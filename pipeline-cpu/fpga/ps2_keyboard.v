`ifndef __PS2_KEYBOARD_V__
`define __PS2_KEYBOARD_V__
`timescale 1ns / 1ps

module ps2_keyboard(
    input  wire       clk,
    input  wire       reset,
    input  wire       ps2_clk,
    input  wire       ps2_data,
    
    input  wire       key_read_acknowledge,
    output wire [7:0] key_code,
    output wire       key_ready,
    output wire       overflow
);

    reg [2:0] ps2_clk_sync;
    wire sampling = ps2_clk_sync[2] & ~ps2_clk_sync[1];
    
    reg [9:0] buffer;
    reg [3:0] bit_cnt;
    
    reg [7:0] fifo [7:0];
    reg [2:0] w_ptr, r_ptr;
    
    reg ready_reg;
    reg overflow_reg;
    
    assign key_ready = ready_reg;
    assign key_code = fifo[r_ptr];
    assign overflow = overflow_reg;
    
    reg key_read_acknowledge_sync0;
    reg key_read_acknowledge_sync1;
    reg key_read_acknowledge_d1;
    
    always @(posedge clk) begin
        if (reset) begin
            ps2_clk_sync <= 3'b111;
            bit_cnt <= 4'd0;
            w_ptr <= 3'd0;
            r_ptr <= 3'd0;
            ready_reg <= 1'b0;
            overflow_reg <= 1'b0;
            key_read_acknowledge_sync0 <= 1'b0;
            key_read_acknowledge_sync1 <= 1'b0;
            key_read_acknowledge_d1 <= 1'b0;
        end
        else begin
            // 同步PS/2时钟
            ps2_clk_sync <= {ps2_clk_sync[1:0], ps2_clk};

            // 跨时钟域
            key_read_acknowledge_sync0 <= key_read_acknowledge;
            key_read_acknowledge_sync1 <= key_read_acknowledge_sync0;
            key_read_acknowledge_d1 <= key_read_acknowledge_sync1;
            
            // 读取确认
            if (ready_reg && !key_read_acknowledge_d1 && key_read_acknowledge_sync1) begin
                if (w_ptr != r_ptr) begin  // FIFO非空
                    r_ptr <= r_ptr + 3'd1;
                    if ((r_ptr + 3'd1) == w_ptr) begin  // 读取后FIFO空
                        ready_reg <= 1'b0;
                    end
                end
            end
            
            // PS/2时钟下降沿写
            if (sampling) begin
                if (bit_cnt == 4'd10) begin 
                    if ((buffer[0] == 0) && ps2_data && (^buffer[9:1])) begin
                        // full
                        if ((w_ptr + 3'd1) == r_ptr) begin
                            overflow_reg <= 1'b1;
                        end
                        fifo[w_ptr] <= buffer[8:1];
                        w_ptr <= w_ptr + 3'd1;
                        ready_reg <= 1'b1;
                    end
                    bit_cnt <= 4'd0;
                end
                else begin
                    buffer[bit_cnt] <= ps2_data;
                    bit_cnt <= bit_cnt + 4'd1;
                end
            end
        end
    end

endmodule
`endif
