`timescale 1ns / 1ps
`include "definition.vh"

module tb_stallable_pipeline;

    // 参数声明
    parameter WIDTH = `PR_DATA_WIDTH;

    // 信号声明
    reg         	clk;
    reg         	rst;
    reg         	validin;
    reg [WIDTH-1:0] 	datain;
    reg         	out_allow;
    wire        	validout;
    wire [WIDTH-1:0] 	dataout;

    //---------------------------------------------------------------------
    // 实例化被测模块
    //---------------------------------------------------------------------
    stallable_pipeline sp(
        .clk(clk),
        .rst(rst),
        .validin(validin),
        .datain(datain),
        .out_allow(out_allow),
        .validout(validout),
        .dataout(dataout)
    );

    always begin
    	forever #5 clk = ~clk;
        if (clk == 1)
        begin
            counter = counter + 1;
        end
    end

    integer counter = 0;
    
    initial begin
        // 初始化信号
        clk = 0; // 设置初始值为 0
        rst = 1'b1;
        validin = 1'b0;
        datain = `PR_DATA_WIDTH'b0;
        out_allow = 1'b1;

	    // 打开 VCD 波形记录
        $dumpfile("sp.vcd");
        $dumpvars(0, tb_stallable_pipeline);

        #10 
        rst = 1'b0; // 释放复位

        //--------------------------------------------------
        // 场景一：正常传输
        //--------------------------------------------------
        //datain = `PR_DATA_WIDTH'hDEADBEEFDEADBEEFDEADBEEF0;
	    datain = {`PR_DATA_WIDTH{1'b1}};
        validin = 1'b1;
        #10 validin = 1'b0;

        #40; // 等待数据通过所有阶段

        //--------------------------------------------------
        // 场景二：out_allow 被拉低，阻塞 stage4
        //--------------------------------------------------
        $display("Blocking output by setting out_allow = 0");

        datain = 32'hCAFEBABE;
        validin = 1'b1;
        #10 validin = 1'b0;
        out_allow = 1'b0;
        #40; // 阻塞阶段4，观察 pipe4_valid 是否保持

        //--------------------------------------------------
        // 场景三：恢复输出并清空流水线
        //--------------------------------------------------
        $display("Resuming output by setting out_allow = 1");
        out_allow = 1'b1;
	    #40

        //--------------------------------------------------
        // 场景四：插入复位信号
        //--------------------------------------------------
        $display("Asserting reset...");
        rst = 1'b1;

        #20 rst = 1'b0;

        #50 $finish;
    end

endmodule