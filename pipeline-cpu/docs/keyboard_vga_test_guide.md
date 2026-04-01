# 键盘输入→VGA显示测试说明

## 文件清单

### 1. 汇编程序
- `test/keyboard_vga_test.asm` - 汇编源代码
- `test/keyboard_vga_test.hex` - 机器码文件

### 2. 测试平台
- `tb/keyboard_vga_tb.v` - 测试平台文件

### 3. 数据文件
- `dmem_init.hex` - 扫描码→ASCII转换表初始化文件
- `inst.txt` - 指令存储器初始化文件（已复制自keyboard_vga_test.hex）

### 4. 修改的文件
- `rtl/utils/dmem.v` - 添加了条件编译的初始化支持

## 程序功能

### 汇编程序工作流程：
```
1. 初始化I/O地址寄存器
   - x5 = 0xffff0014 (键盘状态地址)
   - x6 = 0xffff0010 (键盘数据地址)
   - x7 = 0xffff0020 (VGA显示地址)
   - x9 = 0 (VGA显示位置偏移)
   - x12 = 0 (转换表基地址)

2. 主循环 (poll_loop):
   a. 轮询键盘状态 [0xffff0014]
   b. 如果有按键，读取扫描码 [0xffff0010]
   c. 查表转换：ASCII = dmem[扫描码]
   d. 写入VGA：[0xffff0020 + 偏移] = ASCII
   e. 偏移++，跳转回a
```

### I/O地址映射：
| 地址 | 功能 | 说明 |
|------|------|------|
| 0xffff0010 | 键盘数据 | 读取PS/2扫描码 |
| 0xffff0014 | 键盘状态 | bit0=1表示有按键 |
| 0xffff0020 | VGA显示 | 写入ASCII码显示字符 |

### 扫描码→ASCII转换表（部分）：
| 扫描码 | ASCII | 字符 |
|--------|-------|------|
| 0x1C | 0x61 | 'a' |
| 0x32 | 0x62 | 'b' |
| 0x21 | 0x63 | 'c' |
| 0x29 | 0x20 | 空格 |
| 0x16 | 0x31 | '1' |
| 0x5A | 0x0A | 回车 |

## 运行测试

### 使用Vivado仿真：
```tcl
# 1. 创建项目
# 2. 添加所有RTL文件和测试文件
# 3. 设置顶层模块为 keyboard_vga_tb
# 4. 运行仿真
```

### 使用ModelSim：
```tcl
# 编译文件
vlog rtl/**/*.v
vlog fpga/*.v
vlog tb/keyboard_vga_tb.v

# 运行仿真
vsim -novopt work.keyboard_vga_tb
run -all
```

## 预期输出

测试平台会自动发送以下扫描码：
1. 0x1C ('a')
2. 0x32 ('b')
3. 0x21 ('c')
4. 0x29 (空格)
5. 0x16 ('1')
6. 0x33 ('h')
7. 0x43 ('i')

预期VGA显示内容：
```
Position 0: 0x61 ('a')
Position 1: 0x62 ('b')
Position 2: 0x63 ('c')
Position 3: 0x20 (' ')
Position 4: 0x31 ('1')
Position 5: 0x68 ('h')
Position 6: 0x69 ('i')
```

## 关键技术点

### 1. PS/2协议模拟
- 时钟频率：约12.5kHz
- 数据帧：11位（起始+8数据+校验+停止）
- LSB先发送

### 2. 扫描码到ASCII转换
- 使用数据内存作为转换表
- 通过lbu指令查表
- 支持256个扫描码映射

### 3. VGA显示
- 字符内存：80×30 = 2400字节
- 通过sb指令写入
- font_rom将ASCII转换为点阵

## 故障排除

### 1. 仿真不运行
- 检查`define DMEM_INIT是否定义
- 确认inst.txt和dmem_init.hex在正确位置

### 2. 键盘无响应
- 检查PS/2时钟频率（应在10-16kHz）
- 确认数据格式正确（11位帧）

### 3. VGA显示错误
- 检查转换表数据
- 确认地址映射正确

## 扩展功能

可以扩展的功能：
1. 支持Shift键（大写字母）
2. 支持更多特殊字符
3. 添加光标显示
4. 实现退格键功能
5. 添加多行文本支持
