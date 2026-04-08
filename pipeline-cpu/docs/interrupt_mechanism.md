# 流水线 CPU 中断机制说明

## 1. 结论摘要

当前设计已经具备可工作的机器态外部中断主路径：
- 外设输入 ext_interrupt
- CSR 中形成 mip[11] 待决位
- IF 阶段根据 mstatus.MIE、mie[11]、mip[11] 产生 interrupt_taken
- PC 跳转到 mtvec
- CSR 自动保存 mepc/mcause 并关闭全局中断
- 处理中通过 mret 返回，并恢复 MIE

当前未完整实现：
- ecall 异常入口（目前控制路径未完整接入）
- 软中断（MSIP）触发链路
- 定时器中断（MTIP）触发链路

说明：本项目中寄存器初始化策略按当前设计保留，不在本说明中修改。

## 2. 当前实现的信号链路

### 2.1 顶层连接

文件: rtl/core/pipeline_top.v

- pipeline_top 通过 ext_interrupt 输入接收外部中断请求。
- pipeline_top 实例化 csr_regs，输出 mstatus/mie/mip/mtvec/mepc/mcause。
- pipeline_top 将 global_interrupt_enable = mstatus[3] 送入 IF_stage。

### 2.2 中断响应判定

文件: rtl/core/IF_stage.v

核心逻辑：
- ext_interrupt_pending = mie[11] & mip[11] & global_interrupt_enable
- interrupt_taken = ext_interrupt_pending & ID_allowin

含义：
- 必须同时满足全局使能、外部中断使能、外部中断待决。
- 仅在流水线可接收条件下（ID_allowin）正式取中断，避免时序冲突。

### 2.3 中断/跳转优先级

文件: rtl/utils/NPC.v

NPC 优先级：
1) mret_taken
2) interrupt_taken
3) Branch_taken
4) Jal_taken
5) Jalr_taken
6) PC + 4

这意味着处理中返回（mret）优先级最高，其次是中断入口。

### 2.4 CSR 在中断时的自动保存与恢复

文件: rtl/utils/csr_regs.v

中断进入时：
- mepc <= current_PC
- mcause <= 0x8000000B（最高位 1 表示中断，异常号 11 表示外部中断）
- mstatus.MPIE <= mstatus.MIE
- mstatus.MIE <= 0

mret 时：
- mstatus.MIE <= mstatus.MPIE
- mstatus.MPIE <= 1

此外：
- mip[11] 由 ext_interrupt 直接驱动。
- mtvec 缺省基址由 definition.vh 中 MTVEC_BASE 给出。

### 2.5 流水线冲刷

文件: rtl/hazard/hazard_detect.v

- FLUSH_IFID 在以下事件触发：Branch/Jal/Jalr/mret/interrupt
- 这样可保证中断进入和返回时，前级错误路径指令被清除。

## 3. 当前中断能力边界

### 3.1 已可用

- 外部中断：可用
- mret 返回：可用
- 基本 CSR（mstatus/mie/mip/mtvec/mepc/mcause）：可访问

### 3.2 未完整

- ecall：未完整接入异常入口
- 软中断：仅有位定义，缺少触发源和判定逻辑
- 定时器中断：仅有位定义，缺少计数器/触发源和判定逻辑

相关位定义见: rtl/include/definition.vh
- MIE_MSIE / MIP_MSIP / CAUSE_SOFTWARE
- MIE_MTIE / MIP_MTIP / CAUSE_TIMER

## 4. 后续扩展建议（软中断 + 定时器）

建议按最小可用路径分两步加，先保证可测，再逐步完善规范细节。

### 4.1 软中断（MSIP）

建议改动点：
1) rtl/utils/csr_regs.v
- 增加 mip[3] 的可置位来源（例如 MMIO 写入、测试口、或内部寄存器触发）。
- 保持与 mie[3]、mstatus[3] 联动。

2) rtl/core/IF_stage.v
- 将 pending 判定从仅 bit11 扩展为多源优先级判定：
  - 外部中断（MEIP）
  - 定时器中断（MTIP）
  - 软中断（MSIP）

3) rtl/utils/csr_regs.v
- interrupt_taken 时根据实际来源写 mcause：
  - 外部中断: 0x8000000B
  - 定时器中断: 0x80000007
  - 软中断: 0x80000003

### 4.2 定时器中断（MTIP）

建议改动点：
1) 新增或复用计时源
- 可在 fpga 侧增加一个简单递增计数器，到阈值时置位 timer_irq。

2) rtl/utils/csr_regs.v
- mip[7] 由 timer_irq 置位。
- 可选支持软件清除 pending 位。

3) IF 阶段中断选择
- 和软中断一样纳入统一 pending 仲裁。

### 4.3 ecall 异常（建议你下一步优先补）

目标：达到“外部中断 + mret + ecall”中等完备度。

建议改动点：
1) rtl/utils/ctrl.v 或 rtl/core/ID_stage.v
- 识别 ecall 指令（opcode=1110011, funct3=000, imm=0）。
- 产生异常入口控制信号（例如 exception_taken）。

2) rtl/utils/csr_regs.v
- 异常写入 mcause（最高位为 0，ecall from M-mode 可用 11）。
- 保存 mepc。

3) rtl/utils/NPC.v
- 让异常入口同样跳转 mtvec（可与中断共用入口，靠 mcause 区分）。

4) hazard_detect.v
- 将 exception_taken 纳入 FLUSH_IFID 触发条件。

## 5. 推荐验证用例

### 5.1 外部中断回归

可复用: sim/interrupt_test/interrupt_tb.v

关键检查：
- interrupt_taken 是否拉高
- PC 是否跳转到 mtvec
- mcause 是否为 0x8000000B
- mret 后 MIE 是否恢复

### 5.2 软中断/定时器新增回归

新增最小测试：
- 软中断：人工置位 MSIP，验证进入中断并得到 mcause=0x80000003
- 定时器：计数器触发 MTIP，验证 mcause=0x80000007

### 5.3 ecall 新增回归

最小程序：
- 主程序执行 ecall
- 处理程序读取 mcause/mepc 并写回标志
- mret 返回后继续执行

通过标准：
- 异常能进入 mtvec
- mcause 正确
- mepc 指向触发点
- 返回后程序可继续执行

## 6. 实施顺序建议

1) 先补 ecall（最贴合当前目标）
2) 再补软中断触发链路（MSIP）
3) 最后补定时器触发链路（MTIP）
4) 每补一项立即加最小回归 testbench，避免一次改太多导致定位困难
