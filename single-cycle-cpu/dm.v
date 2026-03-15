module dm(
    input clk,
    input DMWr,
    input [6:0] addr,
    input [31:0] din,
    output reg [31:0] dout
);
    reg [31:0] RAM [127:0];

    integer i;
    initial begin
        for (i = 0; i < 128; i = i + 1)
            RAM[i] = 32'b0;
    end

    // 同步写
    always @(posedge clk) begin
        if (DMWr) RAM[addr] <= din;
    end

    // 异步读（组合逻辑，单周期CPU需要）
    always @(*) begin
        dout = RAM[addr];
    end
endmodule