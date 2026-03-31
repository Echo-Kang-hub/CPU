`timescale 1ns / 1ps

module vga_display_tb;
    reg clk;
    reg reset;
    
    // CPU write interface
    reg  [12:0] cpu_addr;
    reg  [7:0]  cpu_char;
    reg         cpu_we;
    
    // VGA output
    wire [3:0] vga_r;
    wire [3:0] vga_g;
    wire [3:0] vga_b;
    wire       vga_hsync;
    wire       vga_vsync;
    
    // Test status
    integer hsync_count;
    integer vsync_count;
    integer frame_count;
    reg test_passed;
    reg test_failed;
    
    // Global cycle counter for safety
    integer global_cycle_cnt;
    parameter MAX_GLOBAL_CYCLES = 5000000; // 5M cycles max
    
    // Instantiate VGA display
    vga_display u_vga(
        .clk(clk),
        .reset(reset),
        .cpu_addr(cpu_addr),
        .cpu_char(cpu_char),
        .cpu_we(cpu_we),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync)
    );
    
    // Clock generation - 25MHz (40ns period) with safety limit
    initial begin
        clk = 0;
        // Safety: run for max 100ms (100_000_000 ns) then stop
        #100_000_000;
        $display("ERROR: Simulation timeout after 100ms");
        $finish;
    end
    
    // Global cycle counter with safety limit
    initial begin
        global_cycle_cnt = 0;
        forever begin
            @(posedge clk);
            global_cycle_cnt = global_cycle_cnt + 1;
            if (global_cycle_cnt >= MAX_GLOBAL_CYCLES) begin
                $display("ERROR: Global cycle limit reached (%0d cycles)", MAX_GLOBAL_CYCLES);
                $finish;
            end
        end
    end
    
    always #20 clk = ~clk;
    
    // HSync counter - detect rising edge of hsync
    reg prev_hsync;
    reg hsync_pulse_active;
    always @(posedge clk) begin
        if (reset) begin
            hsync_count <= 0;
            prev_hsync <= 1;
            hsync_pulse_active <= 0;
        end else begin
            prev_hsync <= vga_hsync;
            // Detect falling edge (end of sync pulse)
            if (prev_hsync && !vga_hsync && hsync_pulse_active) begin
                hsync_count <= hsync_count + 1;
                hsync_pulse_active <= 0;
            end
            // Detect rising edge (start of sync pulse)
            if (!prev_hsync && vga_hsync) begin
                hsync_pulse_active <= 1;
            end
        end
    end
    
    // VSync counter - detect rising edge of vsync
    reg prev_vsync;
    reg vsync_pulse_active;
    always @(posedge clk) begin
        if (reset) begin
            vsync_count <= 0;
            frame_count <= 0;
            prev_vsync <= 1;
            vsync_pulse_active <= 0;
        end else begin
            prev_vsync <= vga_vsync;
            // Detect falling edge (end of frame sync)
            if (prev_vsync && !vga_vsync && vsync_pulse_active) begin
                vsync_count <= vsync_count + 1;
                frame_count <= frame_count + 1;
                $display("INFO: Frame %0d completed at time %0t", frame_count, $time);
                vsync_pulse_active <= 0;
            end
            // Detect rising edge (start of frame sync)
            if (!prev_vsync && vga_vsync) begin
                vsync_pulse_active <= 1;
            end
        end
    end
    
    // Test sequence with timeout protection
    integer wait_cnt;
    parameter MAX_WAIT = 2500000;  // Max cycles to wait (100ms at 40ns/cycle)
    
    initial begin
        $dumpfile("vga_display_tb.vcd");
        $dumpvars(0, u_vga.vga_hsync);
        $dumpvars(0, u_vga.vga_vsync);
        
        // Initialize
        reset = 1;
        cpu_addr = 0;
        cpu_char = 0;
        cpu_we = 0;
        hsync_count = 0;
        vsync_count = 0;
        frame_count = 0;
        test_passed = 0;
        test_failed = 0;
        wait_cnt = 0;
        
        // Release reset
        #100;
        reset = 0;
        #100;
        
        // Write some characters to display
        // Address format: row * 80 + col
        // Row 0, Col 0 -> 'A' (ASCII 0x41)
        cpu_addr = 0;        // row 0, col 0
        cpu_char = 8'h41;    // 'A'
        cpu_we = 1;
        #40;
        cpu_we = 0;
        
        // Row 0, Col 1 -> 'B'
        cpu_addr = 1;
        cpu_char = 8'h42;
        cpu_we = 1;
        #40;
        cpu_we = 0;
        
        // Row 1, Col 0 -> 'C'
        cpu_addr = 80;       // row 1, col 0
        cpu_char = 8'h43;
        cpu_we = 1;
        #40;
        cpu_we = 0;
        
        // Wait for 2 complete frames with timeout protection
        $display("INFO: Starting frame wait loop (max %0d cycles)", MAX_WAIT);
        while (frame_count < 2 && wait_cnt < MAX_WAIT) begin
            @(posedge clk);
            wait_cnt = wait_cnt + 1;
            // Additional safety check
            if (global_cycle_cnt >= MAX_GLOBAL_CYCLES) begin
                $display("ERROR: Global cycle limit reached during frame wait");
                test_failed = 1;
                $finish;
            end
        end
        $display("INFO: Frame wait loop completed (wait_cnt=%0d, frame_count=%0d)", wait_cnt, frame_count);
        
        // Verify test results
        if (frame_count >= 2 && hsync_count >= 1000) begin
            test_passed = 1;
            $display("PASS: VGA is working correctly");
            $display("  - Frames generated: %0d", frame_count);
            $display("  - HSync pulses: %0d", hsync_count);
        end else if (wait_cnt >= MAX_WAIT) begin
            test_failed = 1;
            $display("FAIL: Test timeout - VGA not generating frames");
            $display("  - Frames generated: %0d (expected >= 2)", frame_count);
            $display("  - HSync pulses: %0d", hsync_count);
        end else begin
            test_failed = 1;
            $display("FAIL: VGA not working properly");
            $display("  - Frames generated: %0d (expected >= 2)", frame_count);
            $display("  - HSync pulses: %0d (expected >= 1000)", hsync_count);
        end
        
        #1000;
        $finish;
    end
    
    // Monitor key signals - limited duration to prevent overflow
    integer mon_cnt;
    initial begin
        #40;
        mon_cnt = 0;
        // Monitor for first 1000 cycles only
        repeat(1000) begin
            @(posedge clk);
            mon_cnt = mon_cnt + 1;
            if (mon_cnt % 1000 == 0) begin
                $display("Time=%0t h_cnt=%d v_cnt=%d hsync=%b vsync=%b", 
                         $time, u_vga.h_cnt, u_vga.v_cnt, vga_hsync, vga_vsync);
            end
        end
        $display("INFO: Monitoring complete");
    end
    
    // Safety watchdog - detect potential infinite loops
    initial begin
        #50_000_000; // 50ms
        if (!test_passed && !test_failed) begin
            $display("WARNING: Test taking too long, checking status...");
            $display("  - Current frame count: %0d", frame_count);
            $display("  - Current hsync count: %0d", hsync_count);
        end
    end

endmodule