module PC(
    input clk,
    input reset,
    input PCWrite,
    input [31:0] NPC_addr,
    output reg [31:0] PC_addr
);

always @(posedge clk or posedge reset) begin 
    if(reset) PC_addr <= 32'b0;
    else if(PCWrite) PC_addr <= NPC_addr;
end
endmodule