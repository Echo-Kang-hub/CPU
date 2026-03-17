module PC_Unit(
    input clk,
    input rstn,
    input [31:0] NPC,
    input PCwr,
    output reg [31:0] PC
);

    always @(posedge clk or negedge rstn) begin 
        if(!rstn) PC <= 32'b0;
        else if(PCwr) PC <= NPC;
    end
endmodule