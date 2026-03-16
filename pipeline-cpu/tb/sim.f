// tb/sim.f 的内容
// 1. 告诉编译器头文件在哪 (+incdir+ 是 Verilog 专门用来指定 include 路径的语法)
+incdir+../rtl/include

// 2. 把所有核心设计文件加进来 (支持通配符)
../rtl/core/*.v
../rtl/common/*.v

// 3. 把测试平台加进来
pipeline_tb.v

// 执行 iverilog -o sim.out -c sim.f