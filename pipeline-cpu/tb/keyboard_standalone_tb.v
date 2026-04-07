`timescale 1ns / 1ps

module keyboard_vga_standalone_tb();

    reg clk;
    reg reset;
    reg ps2_clk;
    reg ps2_data;
    
    // Keyboard
    wire [7:0] key_code;
    wire key_ready;
    reg key_read;
    
    ps2_keyboard U_KBD (
        .clk                  (clk),
        .reset                (reset),
        .ps2_clk              (ps2_clk),
        .ps2_data             (ps2_data),
        .key_read_acknowledge (key_read),
        .key_code             (key_code),
        .key_ready            (key_ready)
    );
    
    // 时钟
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // PS/2发送任务
    task send_bit;
        input bit_val;
        begin
            ps2_data = bit_val;
            #40000;
            ps2_clk = 0;
            #40000;
            ps2_clk = 1;
        end
    endtask
    
    task send_ps2_code;
        input [7:0] code;
        reg parity;
        begin
            parity = ~(code[0] ^ code[1] ^ code[2] ^ code[3] ^ 
                       code[4] ^ code[5] ^ code[6] ^ code[7]);
            
            #1000;
            send_bit(0);
            send_bit(code[0]);
            send_bit(code[1]);
            send_bit(code[2]);
            send_bit(code[3]);
            send_bit(code[4]);
            send_bit(code[5]);
            send_bit(code[6]);
            send_bit(code[7]);
            send_bit(parity);
            send_bit(1);
            #40000;
        end
    endtask
    
    initial begin
        $display("Keyboard Test");
        
        reset = 1;
        ps2_clk = 1;
        ps2_data = 1;
        key_read = 1;
        
        #1000;
        reset = 0;
        #1000;
        
        $display("Sending key 0x1c...");
        send_ps2_code(8'h1c);
        #100000;
        
        if (key_ready) begin
            $display("Key Ready! code=0x%h", key_code);
            key_read = 0;
            #100;
            key_read = 1;
            #1000;
            $display("After ack: key_ready=%b", key_ready);
        end
        
        $display("Test done");
        $finish;
    end

endmodule
