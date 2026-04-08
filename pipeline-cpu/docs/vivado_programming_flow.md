# Vivado 下板流程（pipeline-cpu）

## 1. 关键结论

- imem 不能直接放 asm 源码。
- imem 需要机器码初始化文件（每行 32-bit 十六进制指令）。
- fibonacci_vga 和 sorting_vga 需要分别生成各自镜像并分别下板。

依据：
- rtl/utils/imem.v 使用 $readmemh("inst.txt", ROM)
- fpga/xgriscv_fpga_top.v 中 U_IM 直接实例化 imem

## 2. 本仓库新增脚本

- scripts/build_program_image.ps1
  - 功能：把 asm 程序编译并转换成 inst.txt
- scripts/run_program_sim.ps1
  - 功能：生成 inst.txt 后直接跑 system_full_tb 仿真

## 3. 使用示例（PowerShell）

### 3.1 生成 Fibonacci 指令镜像

```powershell
cd d:/FileDownload/Projects/CPU/pipeline-cpu
./scripts/build_program_image.ps1 -Program fibonacci_vga
```

### 3.2 生成 Sorting 指令镜像

```powershell
cd d:/FileDownload/Projects/CPU/pipeline-cpu
./scripts/build_program_image.ps1 -Program sorting_vga
```

### 3.3 先仿真再下板

```powershell
cd d:/FileDownload/Projects/CPU/pipeline-cpu
./scripts/run_program_sim.ps1 -Program fibonacci_vga
```

## 4. Vivado 工程设置建议

1. 顶层选择 fpga/xgriscv_fpga_top.v
2. 约束使用 Nexys4 对应 xdc
3. 确保以下内存初始化文件加入工程并被综合/实现阶段可见：
   - inst.txt
   - font_data.mem
   - dmem_init.hex（若你的程序依赖数据存储预加载）
4. 生成 bitstream 后 Program Device

## 5. 切换程序的正确方式

1. 运行 build_program_image.ps1 生成新的 inst.txt
2. 重新综合/实现/生成 bitstream
3. 重新下板

注意：只替换文件但不重新生成 bitstream，板上不会更新程序。

## 6. 常见问题

- 报错“未检测到 RISC-V GNU 工具链”
  - 说明机器上没有 riscv32-unknown-elf-as/ld/objcopy（或同类前缀）
- 报错“汇编失败”
  - 说明 asm 语法与工具链不兼容，需要修正指令语法
- 板上黑屏
  - 先检查 font_data.mem 是否在工程
  - 再检查程序是否确实往 0xFFFF0020 区间写入
