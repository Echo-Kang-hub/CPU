# RISCV-Pipelined-SoC

基于 RISC-V RV32I 指令集架构的 CPU 实现项目，包含单周期 CPU、流水线 CPU、带中断机制的流水线 CPU 及 VGA/Keyboard 外设支持的完整 SoC。

## 开发环境

### 硬件平台

- **开发板**: Nexys4 DDR (Artix-7 100T CSG324)
- **芯片**: XC7A100TCSG324-1

### 软件工具

- **IDE**: VSCode
- **FPGA 开发工具**: Vivado 18.3
- **RISC-V 汇编器**: Venus (生成机器码 inst.txt)
  - Venus 将汇编程序转换为十六进制机器码
  - 输出格式：每行 32-bit 十六进制指令
- **仿真工具**: Icarus Verilog (iverilog) + GTKWave

### 项目结构

```
RISCV-Pipelined-SoC/
├── single-cycle-cpu/     # 单周期 CPU 参考实现
├── pipeline-cpu/         # 主流水线 CPU 实现
│   ├── rtl/              # RTL 源代码
│   ├── fpga/             # FPGA 顶层及外设
│   ├── tb/               # Testbench
│   ├── sim/              # 仿真脚本
│   ├── test/             # RISC-V 汇编测试程序
│   ├── xdc/              # 约束文件
│   ├── docs/             # 详细设计文档
│   └── scripts/          # 构建脚本
├── example/              # 流水线示例代码
└── guide/                # 实验指导文档
```

## 分支结构

| 分支 | 描述 | 特性 |
|------|------|------|
| `main` | 基础流水线 CPU | 五级流水线、 数据转发、冒泡 |
| `feature-interrupt` | 带中断的流水线 CPU | 外部中断、CSR (mstatus/mie/mip/mtvec/mepc/mcause)、mret |
| `feature-fpga` | 完整 SoC 实现 | VGA 显示、PS2 Keyboard、中断机制 |

### 各分支功能说明

#### main - 流水线 CPU

- 五级流水 线：IF、ID、EX、MEM、WB
- 数据前推机制
- 冒险检测与冒泡处理
- 支持 RV32I 基本指令集

#### feature-interrupt - 带外部中断的流水线 CPU

- 在 main 基础上增加：
- 外部中断支持 (ext_interrupt)
- CSR 寄存器组
- 中断入口 (mtvec) 和返回 (mret)
- 流水线冲刷机制

#### feature-fpga - 完整 SoC 实现 (推荐)

- 在 feature-interrupt 基础上增加：
- VGA 显示控制器 (640x480 @ 60Hz)
- PS2 Keyboard 键盘接口 (支持中断)
- 中断驱动的外设交互
- 完整 SoC 顶层
- 已验证可运行程序：fibonacci、sorting、snake、typing_vga

## 快速开始

### 1. 环境准备

安装必要工具：

- Vivado 18.3 (添加到系统 PATH)
- Venus RISC-V 模拟器 (用于生成机器码)
- Icarus Verilog (仿真用)

验证命令：
```bash
vivado -version
iverilog -V
```

### 2. 仿真测试

```powershell
# 在 pipeline-cpu 目录下
cd pipeline-cpu
.\compile_debug.sh
```

### 3. FPGA 下载

1. 打开 Vivado，选择 `pipeline-cpu/fpga/xgriscv_fpga_top.v` 作为顶层
2. 添加约束文件 `xdc/Nexys4DDR_CPU.xdc`
3. 确保 `inst.txt`、`font_data.mem` 等内存在工程中
4. 综合、实现、生成 bitstream
5. Program Device 下载到开发板

### 4.切换程序

```powershell
# 生成新程序镜像
cd pipeline-cpu
.\scripts\build_program_image.ps1 -Program <程序名>

# 重新综合并下载
```

可用程序示例：`fibonacci_vga`、`sorting_vga`

## 内置程序 (coe/asm)

| 程序 | 功能 | 特性 |
|------|------|------|
| fibonacci | 计算斐波那契数列 | CPU 计算 |
| fibonacci_keyboard | 斐波那契数列 (键盘输入) | 键盘键入、VGA 显示 |
| sorting | 排序算法 | CPU 计算 |
| snake | 贪吃蛇游戏 | 键盘控制、VGA 显示 |
| typing_vga | 打字练习 | 键盘键入、VGA 显示 |
| keyboard_vga | 键盘测试 | 键盘键入、VGA 显示 |

程序文件位于 `pipeline-cpu/coe/` 目录 (.coe) 和 `pipeline-cpu/test/` 目录 (.asm)。

### 程序切换流程

1. Venus 输出机器码 (0x... 格式)
2. 使用脚本转换为纯 hex 和 .coe 格式
3. 放入 Vivado 工程，重新综合、实现、下载

### 脚本工具

位于 `pipeline-cpu/scripts/` 目录：

| 脚本 | 功能 |
|------|------|
| `prep-machine-code.py` | 将 0x 前缀机器码转为纯 hex 格式 |
| `prep-coe-code.py` | 将纯 hex 格式转为 Vivado .coe 文件 |
| `build_program_image.ps1` | 一键构建程序镜像 |

快速构建：
```powershell
cd pipeline-cpu
.\scripts\build_program_image.ps1 -Program fibonacci_vga
```

## 技术文档

详细设计说明请参考 `pipeline-cpu/docs/` 目录：

- `vivado_programming_flow.md` - Vivado 下板流程
- `interrupt_mechanism.md` - 中断机制说明
- `keyboard_vga_test_guide.md` - VGA/Keyboard 测试指南

## 指令集

支持 RV32I 基本指令集，包括：

- **算术**: add, sub, addi
- **逻辑**: and, or, xor, andi, ori, xori
- **移位**: sll, srl, sra, slli, srli, srai
- **比较**: slt, sltu, slti, sltiu
- **加载/存储**: lw, lb, lbu, sw, sb
- **分支**: beq, bne, blt, bge, bltu, bgeu
- **跳转**: jal, jalr
- **控制**: lui, auipc
- **异常**: ecall, mret (RISC-V 特权指令)

## 约束引脚

关键引脚映射 (Nexys4 DDR)：

- 时钟: E3 (100MHz)
- 复位: C12 (BTNC)
- VGA: H5, H4, J2, G3 等
- PS2: J15, J16

完整约束见 `pipeline-cpu/xdc/Nexys4DDR_CPU.xdc`

## 常见问题

1. **报错 "未检测到 RISC-V GNU 工具链"**
   - 确保 riscv32-unknown-elf-* 在系统 PATH 中

2. **imem 无法加载程序**
   - 使用 `build_program_image.ps1` 生成 `inst.txt`，不要直接放 asm

3. **FPGA 黑屏**
   - 检查 font_data.mem 是否在工程中
   - 检查程序是否往 0xFFFF0020 区间写入

4. **VGA 无显示**
   - 确认程序烧录到正确的 bitstream 文件中

## 版权与贡献

本项目为 RISC-V CPU 实验教学项目。