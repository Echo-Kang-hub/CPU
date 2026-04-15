# 流水线CPU中断机制、VGA与键盘仿真使用指南

本指南介绍如何通过仿真文件观察和验证流水线CPU的中断机制、VGA显示和键盘输入功能。

## 1. 仿真文件位置

- 仿真 testbench 文件：`pipeline-cpu/tb/tb_interrupt_vga_keyboard.v`
- 仿真波形输出：`tb_interrupt_vga_keyboard.vcd`（仿真后自动生成）

## 2. 仿真文件结构说明

- `tb_interrupt_vga_keyboard.v` 实例化了顶层模块（如 `xgriscv_fpga_top`），连接了 VGA、键盘、时钟、中断等信号。
- 可在 initial 块中模拟键盘输入、触发中断等操作。
- 通过 `$dumpfile` 和 `$dumpvars` 生成 VCD 波形文件，便于后续分析。

## 3. 仿真运行方法

### 使用 Icarus Verilog（推荐）

1. 进入 `pipeline-cpu/tb/` 目录：
   ```sh
   cd pipeline-cpu/tb
   ```
2. 使用 `sim.f` 编译 testbench：
   ```sh
   iverilog -o sim.vvp -c sim.f
   ```
3. 运行仿真，生成波形文件：
   ```sh
   vvp sim.vvp
   ```
4. 用 GTKWave 打开波形：
   ```sh
   gtkwave tb_interrupt_vga_keyboard.vcd
   ```

### Vivado Simulator

1. 新建仿真工程，添加 `tb_interrupt_vga_keyboard.v`。
2. 运行仿真，导出波形（.wdb 或 .vcd）。

## 4. 观察与分析方法

### 关键信号
- `UUT.U_CPU.interrupt_taken`：CPU中断接收信号，观察其触发时机。
- `vga_r/g/b, vga_hsync, vga_vsync`：VGA输出信号，分析显示内容变化。
- `ps2_clk, ps2_data`：键盘输入信号，模拟按键输入。
- 其他相关信号（如 CPU 状态、PC、寄存器等）。

### 分析步骤
1. 在仿真 initial 块中通过驱动 `ps2_clk`/`ps2_data`，模拟键盘输入。
2. 观察 `UUT.U_MIO.key_interrupt` 和 `UUT.U_CPU.interrupt_taken` 在何时被拉高，分析中断响应。
3. 结合 VGA 信号，查看屏幕内容随输入/中断的变化。
4. 可添加更多信号到波形窗口，辅助调试。

## 5. 示例操作流程

1. 在 `pipeline-cpu/tb/` 下运行 `iverilog -o sim.vvp -c sim.f`。
2. 再运行 `vvp sim.vvp` 生成波形。
3. 用 GTKWave 打开 VCD 文件，添加关键信号进行分析。
4. 观察 CPU 对中断的响应、VGA 显示变化、键盘输入处理等。

## 6. 常见问题
- 仿真时间不够长：适当延长 initial 块中的仿真时间。
- 信号未显示：确认 `$dumpvars` 是否包含目标信号。
- 键盘输入无效：检查 ps2 协议时序和信号驱动方式。

---
如需更复杂的键盘输入或中断测试，可扩展 testbench 逻辑，或参考实际硬件协议文档。
