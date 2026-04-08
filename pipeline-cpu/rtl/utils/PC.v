`timescale 1ns / 1ps
module PC(
    input wire clk,
    input wire reset,
    input wire PCWrite,
    input wire [31:0] NPC_addr,
    output reg [31:0] PC_addr
);

always @(posedge clk or posedge reset) begin 
    if(reset) PC_addr <= 32'b0;
    else if(PCWrite) PC_addr <= NPC_addr;
end
endmodule