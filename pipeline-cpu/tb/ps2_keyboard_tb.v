`timescale 1ns / 1ps

module ps2_keyboard_tb;
    reg clk;
    reg reset;
    reg ps2_clk;
    reg ps2_data;
    reg key_read_acknowledge;

    wire [7:0] key_code;
    wire key_ready;
    wire overflow;

    integer errors;

    ps2_keyboard dut (
        .clk(clk),
        .reset(reset),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .key_read_acknowledge(key_read_acknowledge),
        .key_code(key_code),
        .key_ready(key_ready),
        .overflow(overflow)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;  // 100MHz
    end

    initial begin
        ps2_clk = 1'b1;
        ps2_data = 1'b1;
    end

    task send_scan_code;
        input [7:0] code;
        integer i;
        reg [10:0] frame;
        begin
            frame[0] = 1'b0;         // start
            frame[8:1] = code;       // LSB first
            frame[9] = ~(^code);     // odd parity
            frame[10] = 1'b1;        // stop

            for (i = 0; i < 11; i = i + 1) begin
                ps2_data = frame[i];
                #40 ps2_clk = 1'b0;
                #40 ps2_clk = 1'b1;
            end

            ps2_data = 1'b1;
            #80;
        end
    endtask

    task read_one_byte;
        input [7:0] expected;
        begin
            wait (key_ready == 1'b1);
            #10;
            if (key_code !== expected) begin
                $display("[FAIL] expected=%h got=%h at t=%0t", expected, key_code, $time);
                errors = errors + 1;
            end else begin
                $display("[PASS] got key_code=%h at t=%0t", key_code, $time);
            end

            // active-low acknowledge pulse
            key_read_acknowledge = 1'b0;
            #20;
            key_read_acknowledge = 1'b1;
            #30;
        end
    endtask

    initial begin
        errors = 0;
        reset = 1'b1;
        key_read_acknowledge = 1'b1;

        #50;
        reset = 1'b0;
        #50;

        // A make/break sequence: 1C, F0, 1C
        send_scan_code(8'h1C);
        read_one_byte(8'h1C);

        send_scan_code(8'hF0);
        read_one_byte(8'hF0);

        send_scan_code(8'h1C);
        read_one_byte(8'h1C);

        if (overflow !== 1'b0) begin
            $display("[FAIL] overflow asserted unexpectedly");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("[RESULT] ps2_keyboard basic test PASSED");
        else
            $display("[RESULT] ps2_keyboard basic test FAILED, errors=%0d", errors);

        #100;
        $finish;
    end
endmodule
