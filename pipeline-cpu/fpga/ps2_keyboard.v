`ifndef __PS2_KEYBOARD_V__
`define __PS2_KEYBOARD_V__
`timescale 1ns / 1ps

module ps2_keyboard(
    input  wire clk,
    input  wire reset,
    input  wire ps2_clk,
    input  wire ps2_data,
    
    input  wire       key_read_acknowledge,  // 读取确认（低有效）
    output wire [7:0] key_code,              // 键盘扫描码
    output wire       key_ready,             // 数据就绪
    output wire       overflow               // FIFO溢出
);

    // PS/2时钟同步和下降沿检测
    reg [2:0] ps2_clk_sync;
    wire sampling = ps2_clk_sync[2] & ~ps2_clk_sync[1];
    
    // 接收缓冲区
    reg [9:0] buffer;
    reg [3:0] bit_cnt;
    
    // FIFO队列 (8字节)
    reg [7:0] fifo [7:0];
    reg [2:0] w_ptr, r_ptr;  // 写指针、读指针
    
    // 状态信号
    reg ready_reg;
    reg overflow_reg;
    
    // 输出赋值
    assign key_ready = ready_reg;
    assign key_code = fifo[r_ptr];
    assign overflow = overflow_reg;
    
    // 对跨时钟域 key_read_acknowledge 做双触发同步后再检测下降沿
    reg key_read_sync0;
    reg key_read_sync1;
    reg key_read_d1;
    
    always @(posedge clk) begin
        if (reset) begin
            ps2_clk_sync <= 3'b111;
            bit_cnt <= 4'd0;
            w_ptr <= 3'd0;
            r_ptr <= 3'd0;
            ready_reg <= 1'b0;
            overflow_reg <= 1'b0;
            key_read_sync0 <= 1'b1;
            key_read_sync1 <= 1'b1;
            key_read_d1 <= 1;
        end
        else begin
            // 同步PS/2时钟
            ps2_clk_sync <= {ps2_clk_sync[1:0], ps2_clk};

            // 先把ack同步到本时钟域
            key_read_sync0 <= key_read_acknowledge;
            key_read_sync1 <= key_read_sync0;
            key_read_d1 <= key_read_sync1;
            
            // 处理读取确认 - 检测下降沿（从1变0）
            if (ready_reg && key_read_d1 && !key_read_sync1) begin
                if (w_ptr != r_ptr) begin  // FIFO非空
                    r_ptr <= r_ptr + 3'd1;
                    if (w_ptr == (r_ptr + 3'd1)) begin  // 读取后FIFO空
                        ready_reg <= 1'b0;
                    end
                end
            end
            
            // 在PS/2时钟下降沿采样数据
            if (sampling) begin
                if (bit_cnt == 4'd10) begin  // 收到完整的一帧
                    if ((buffer[0] == 0) &&      // 起始位
                        (ps2_data) &&            // 停止位
                        (^buffer[9:1])) begin    // 奇校验
                        // 检查溢出：写指针下一位等于读指针
                        if ((w_ptr + 3'd1) == r_ptr) begin
                            overflow_reg <= 1'b1;
                        end
                        fifo[w_ptr] <= buffer[8:1];  // 存储扫描码
                        w_ptr <= w_ptr + 3'd1;
                        ready_reg <= 1'b1;
                    end
                    bit_cnt <= 4'd0;  // 准备接收下一帧
                end
                else begin
                    buffer[bit_cnt] <= ps2_data;  // 存储数据位
                    bit_cnt <= bit_cnt + 4'd1;
                end
            end
        end
    end

endmodule
`endif
