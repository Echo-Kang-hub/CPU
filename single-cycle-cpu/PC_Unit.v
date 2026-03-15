module PC_Unit(
    input clk,
    input rstn,
    input [31:0] NPC,
    input PCwr,
    output reg [31:0] PC
);
// 由于主模块下各rstn复位都是异步复位，所以关于rstn的同时集体复位，这里应该采取异步复位，所以敏感列表里应有rstn
always @(posedge clk or negedge rstn) begin 
    if(!rstn) PC <= 32'b0;
    else if(PCwr) PC <= NPC;
end
endmodule