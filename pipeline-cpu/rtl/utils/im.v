`ifndef __IM_V__   
`define __IM_V__
`timescale 1ns / 1ps

module im ( 
    input  wire [7:0]  addr,
    output wire [31:0] dout 
);
    reg [31:0] ROM [0:255];

    initial begin
        $readmemh("inst.txt", ROM); 
    end

    assign dout = ROM[addr];
endmodule
`endif