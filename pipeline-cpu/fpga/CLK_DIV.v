`timescale 1ns / 1ps
module CLK_DIV( input wire clk,
                input wire rst,
                input wire SW15,
                output wire Clk_CPU
              );

// Clock divider

  reg[31:0]clkdiv;

  always @ (posedge clk or posedge rst) begin 
    if (rst) clkdiv <= 0; else clkdiv <= clkdiv + 1'b1; end

  assign Clk_CPU=(SW15)? clkdiv[25] : clkdiv[2];  // SW15 to select slow cpu clock or fast cpu clk

endmodule
