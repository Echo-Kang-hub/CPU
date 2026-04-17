`ifndef __CLK_DIV_V__
`define __CLK_DIV_V__
`timescale 1ns / 1ps

module CLK_DIV #(
                parameter USE_SW15_CLK_SEL = 1'b0,
                parameter FAST_CLKDIV_BIT  = 2,
                parameter SLOW_CLKDIV_BIT  = 25
              )(
                input wire clk,
                input wire rst,
                input wire SW15,
                output wire Clk_CPU
              );

// Clock divider

  reg[31:0]clkdiv;

  always @ (posedge clk or posedge rst) begin 
    if (rst) clkdiv <= 0; else clkdiv <= clkdiv + 1'b1; end

  // Default behavior ignores SW15 and always uses fast CPU clock.
  // To restore SW15 clock selection, set USE_SW15_CLK_SEL to 1.
  assign Clk_CPU = (USE_SW15_CLK_SEL && SW15) ? clkdiv[SLOW_CLKDIV_BIT] : clkdiv[FAST_CLKDIV_BIT];

endmodule
`endif