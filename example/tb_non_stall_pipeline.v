`timescale 1ns / 1ps

module tb_non_stall_pipeline;

    // 参数定义
    parameter WIDTH = 100;

    // 信号声明
    reg         clk;
    reg  [WIDTH-1:0] datain;
    wire [WIDTH-1:0] dataout;

    // 实例化被测模块
    non_stall_pipeline nsp (
        .clk(clk),
        .datain(datain),
        .dataout(dataout)
    );
    
    always begin
        #5 clk = ~clk;
    end

    // 初始激励
    initial begin
    $dumpfile("nsp.vcd");
    $dumpvars(0, tb_non_stall_pipeline);

	$monitor("Time = %0t | datain = %h | dataout = %h", $time, datain, dataout);
	clk = 0;
	datain = 0;

	#10 datain = 100'hDEADBEEFCAFEBABEDEADBEEF0;
	#10 datain = 100'h0000000000000000000000000;
	#10 datain = 100'hFFFFFFFFFFFFFFFFFFFFFFFFF;
	#10 datain = 100'h123456789ABCDEF0123456789;

	#50 $finish;
	end

endmodule