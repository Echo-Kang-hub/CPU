module im (
    input  [6:0]  addr, 
    output [31:0] dout
);
    reg [31:0] ROM [255:0]; 
    assign dout = ROM[addr];
endmodule