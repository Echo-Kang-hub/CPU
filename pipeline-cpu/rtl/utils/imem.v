`ifndef __IM_V__   
`define __IM_V__
`timescale 1ns / 1ps

module imem ( 
    input  wire [6:0]  a,
    output wire [31:0] spo 
);
    reg [31:0] ROM [0:255];

    initial begin
        $readmemh("inst.txt", ROM); 
    end

    assign spo = ROM[a];
endmodule
`endif