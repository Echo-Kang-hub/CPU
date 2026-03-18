`timescale 1ns / 1ps

module im ( 
    input  wire [6:0]  addr,  // PC[8:2] 刚好是 7 位
    output wire [31:0] dout   // 输出的 32 位指令
);
    reg [31:0] ROM [0:127];

    initial begin
        // 读取汇编生成的机器码文件，文件名根据老师要求可改
        $readmemh("inst.txt", ROM); 
    end

    assign dout = ROM[addr];
endmodule