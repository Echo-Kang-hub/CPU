`timescale 1ns / 1ps
`define DMEM_INIT

module keyboard_vga_debug_tb();

    // 时钟和复位
    reg         clk;
    reg         rstn;
    
    // 键盘模拟信号
    reg         ps2_clk;
    reg         ps2_data;
    
    // 直接访问信号
    wire [31:0] pc;
    wire [31:0] instr;
    wire [31:0] dm_addr;
    wire [31:0] dm_wdata;
    wire        dm_we;
    reg  [31:0] dm_rdata;
    
    // I/O 信号
    wire [7:0]  key_code;
    wire        key_ready;
    reg         key_read;
    
    reg  [12:0] vga_addr;
    reg  [7:0]  vga_char;
    reg         vga_we;
    
    // 数据存储器输出
    wire [31:0] dm_rdata_ram;
    
    // 实例化CPU
    pipeline_top U_CPU (
        .clk             (clk),
        .reset           (~rstn),  // 注意：CPU使用reset高有效
        .instr_addr      (pc),
        .instr           (instr),
        .DM_write_addr   (dm_addr),
        .DM_write_data   (dm_wdata),
        .DM_write_enable (dm_we),
        .DM_Type         (),
        .DM_read_data    (dm_rdata),
        .reg_sel         (5'b0),
        .reg_data        ()
    );
    
    // 实例化指令存储器
    imem U_IM (
        .a    (pc[8:2]),
        .spo  (instr)
    );
    
    // 实例化数据存储器
    dmem U_DM (
        .clk    (clk),
        .DMWr   (dm_we & (dm_addr[31:16] != 16'hffff)),
        .DMType (3'b010),
        .addr   (dm_addr),
        .din    (dm_wdata),
        .dout   (dm_rdata_ram)
    );
    
    // 实例化PS/2键盘
    ps2_keyboard U_KBD (
        .clk                  (clk),
        .reset                (~rstn),
        .ps2_clk              (ps2_clk),
        .ps2_data             (ps2_data),
        .key_read_acknowledge (key_read),
        .key_code             (key_code),
        .key_ready            (key_ready)
    );
    
    // 实例化VGA显示
    vga_display U_VGA (
        .clk       (clk),
        .reset     (~rstn),
        .cpu_addr  (vga_addr),
        .cpu_char  (vga_char),
        .cpu_we    (vga_we),
        .vga_r     (),
        .vga_g     (),
        .vga_b     (),
        .vga_hsync (),
        .vga_vsync ()
    );
    
    // I/O 地址解码
    always @(*) begin
        dm_rdata = 32'h0;
        key_read = 1'b0;
        vga_we = 1'b0;
        vga_addr = 13'h0;
        vga_char = 8'h0;
        
        case (dm_addr[31:0])
            32'hffff_0010: begin  // 键盘数据
                dm_rdata = {24'h0, key_code};
                key_read = dm_we;
            end
            32'hffff_0014: begin  // 键盘状态
                dm_rdata = {31'h0, key_ready};
            end
            32'hffff_0020: begin  // VGA
                vga_we = dm_we;
                vga_addr = dm_addr[12:2];
                vga_char = dm_wdata[7:0];
            end
            default: begin
                dm_rdata = dm_rdata_ram;
            end
        endcase
    end
    
    // 时钟生成 (10ns周期)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // PS/2时钟生成 (约10kHz，周期100us)
    // 初始化为高电平，确保同步器正确初始化
    initial begin
        ps2_clk = 1'b1;
        #1;  // 等待1ns确保初始化完成
        forever begin
            #50000 ps2_clk = 1'b0;  // 50us低电平
            #50000 ps2_clk = 1'b1;  // 50us高电平
        end
    end
    
    // 发送PS/2扫描码
    task send_ps2_code;
        input [7:0] code;
        integer i;
        reg parity;
        begin
            parity = ~(code[0] ^ code[1] ^ code[2] ^ code[3] ^ 
                       code[4] ^ code[5] ^ code[6] ^ code[7]);
            
            @(negedge ps2_clk);
            ps2_data = 0;
            @(negedge ps2_clk);
            
            for (i = 0; i < 8; i = i + 1) begin
                ps2_data = code[i];
                @(negedge ps2_clk);
            end
            
            ps2_data = parity;
            @(negedge ps2_clk);
            ps2_data = 1;
            @(negedge ps2_clk);
            ps2_data = 1;
        end
    endtask
    
    // 主测试
    initial begin
        $display("=== Keyboard VGA Debug Test ===");
        
        // 强制初始化所有信号
        rstn = 0;
        ps2_data = 1;
        ps2_clk = 1;
        
        // 等待一段时间让所有模块初始化
        #10000;
        
        // 释放复位
        rstn = 1;
        
        // 等待CPU启动和同步器稳定
        #200000;
        
        // 发送 'a' (0x1C)
        $display("[%0t] Sending 'a' (0x1C)", $time);
        send_ps2_code(8'h1C);
        #2000000;
        
        $finish;
    end
    
    // 监控CPU执行
    always @(posedge clk) begin
        if (rstn && ^pc !== 1'bx) begin
            $display("[%0t] PC=0x%h, Instr=0x%h, DM_Addr=0x%h, DM_WData=0x%h, DM_WE=%b", 
                     $time, pc, instr, dm_addr, dm_wdata, dm_we);
        end
    end
    
    // 监控键盘状态
    always @(posedge clk) begin
        if (key_ready !== U_KBD.key_ready) begin
            $display("[%0t] KEY_READY mismatch! key_ready=%b, U_KBD.key_ready=%b", 
                     $time, key_ready, U_KBD.key_ready);
        end
        if (U_KBD.key_ready) begin
            $display("[%0t] U_KBD.KEY_READY=1, KEY_CODE=0x%h", $time, U_KBD.key_code);
        end
        if (key_read) begin
            $display("[%0t] KEY_READ=1", $time);
        end
        // 调试：监控PS/2控制器内部状态
        if (U_KBD.ps2_clk_fall) begin
            $display("[%0t] PS2_CLK_FALL, bit_cnt=%0d, ps2_data=%b, shift_reg=0x%h", 
                     $time, U_KBD.bit_cnt, ps2_data, U_KBD.shift_reg);
        end
    end
    
    // 监控VGA写入
    always @(posedge clk) begin
        if (vga_we) begin
            $display("[%0t] VGA_WRITE: addr=%0d, char=0x%h ('%c')", 
                     $time, vga_addr, vga_char, vga_char);
        end
    end
    
    // 监控I/O访问
    always @(posedge clk) begin
        if (dm_we && dm_addr[31:16] == 16'hffff) begin
            $display("[%0t] IO_WRITE: addr=0x%h, data=0x%h", $time, dm_addr, dm_wdata);
        end
    end

endmodule
