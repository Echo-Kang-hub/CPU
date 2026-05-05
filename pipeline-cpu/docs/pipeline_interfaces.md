# 流水线 CPU 模块接口与连接详细文档

## 目录

1. [总体架构概览](#1-总体架构概览)
2. [模块清单](#2-模块清单)
3. [各模块接口详细说明](#3-各模块接口详细说明)
4. [流水线总线内容详解](#4-流水线总线内容详解)
5. [模块间完整连接关系](#5-模块间完整连接关系)
6. [画图参考：信号分组汇总](#6-画图参考信号分组汇总)

---

## 1. 总体架构概览

经典五级流水线：**IF → ID → EX → MA → WB**

```
                 ┌─────────────────────────────────────────────────────────────────┐
                 │                        pipeline_top                             │
                 │                                                                 │
  instr_addr ──► │  ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐          │
  instr ────────►│  │ IF  │───►│ ID  │───►│ EX  │───►│ MA  │───►│ WB  │──► RF    │
                 │  │stage│    │stage│    │stage│    │stage│    │stage│   write   │
                 │  └──┬──┘    └──┬──┘    └──┬──┘    └──┬──┘    └─────┘          │
                 │     │          │          │          │                          │
                 │     │    ┌─────┘          │          │                          │
                 │     │    │ Branch/Jal/    │          │                          │
                 │     ◄────┘ Jalr/mret     │          │                          │
                 │     │                     │          │                          │
                 │     │              ┌──────┘          │                          │
                 │     │              │ Forwarding      │                          │
                 │     │              │ (EXMA/MAWB)     │                          │
                 │     │              │                 │                          │
                 │     │         ┌────┘           ┌─────┘                          │
                 │     │         │ Hazard         │ CSR Write                      │
                 │     │         │ Detection      │                                │
                 │  ┌──┴─────────┴──┐          ┌──┴──┐                            │
                 │  │  hazard_detect│          │ CSR │                            │
                 │  │  forwarding   │          │regs │                            │
                 │  └───────────────┘          └─────┘                            │
                 │                                                                 │
                 │  bus_write_enable/addr/data/DM_Type ──► 外部 DMEM              │
                 │  bus_read_data ◄────────────────────── 外部 DMEM              │
                 └─────────────────────────────────────────────────────────────────┘
```

外部连接 (soc_top)：
- **imem**: 指令存储器，接收 instr_addr，输出 instr
- **dmem**: 数据存储器，接收 MA 阶段的写地址/数据/使能，输出读数据

---

## 2. 模块清单

| 模块名 | 文件路径 | 功能描述 |
|--------|---------|---------|
| `IF_stage` | `rtl/core/IF_stage.v` | 取指阶段：PC、NPC、中断判断 |
| `ID_stage` | `rtl/core/ID_stage.v` | 译码阶段：译码、控制、寄存器读、分支判断、冒险检测 |
| `EX_stage` | `rtl/core/EX_stage.v` | 执行阶段：ALU运算、EX级前递 |
| `MA_stage` | `rtl/core/MA_stage.v` | 访存阶段：数据存储器读写、CSR写回 |
| `WB_stage` | `rtl/core/WB_stage.v` | 写回阶段：选择写回数据、生成前递信号 |
| `pipeline_top` | `rtl/core/pipeline_top.v` | 流水线顶层：连接所有流水级和CSR模块 |
| `soc_top` | `rtl/top/soc_top.v` | SoC顶层：连接pipeline_top、imem、dmem |
| `PC` | `rtl/utils/PC.v` | 程序计数器 |
| `NPC` | `rtl/utils/NPC.v` | 下一地址计算（多路选择） |
| `RF` | `rtl/utils/RF.v` | 32x32寄存器文件 |
| `EXT` | `rtl/utils/EXT.v` | 立即数扩展 |
| `ctrl` | `rtl/utils/ctrl.v` | 控制信号生成（组合逻辑译码） |
| `alu` | `rtl/utils/alu.v` | 算术逻辑单元 |
| `csr_regs` | `rtl/utils/csr_regs.v` | CSR寄存器组（mtvec/mie/mip/mstatus/mcause/mepc） |
| `hazard_detect` | `rtl/hazard/hazard_detect.v` | 冒险检测（load-use、ALU-branch等） |
| `forwarding` | `rtl/hazard/forwarding.v` | 数据前递（EX级使用的前递逻辑） |
| `imem` | `rtl/utils/imem.v` | 指令存储器（ROM，2048x32） |
| `dmem` | `rtl/utils/dmem.v` | 数据存储器（RAM，128x32，支持字节/半字/字） |

---

## 3. 各模块接口详细说明

### 3.1 IF_stage — 取指阶段

```verilog
module IF_stage(
    // ===== 时钟与复位 =====
    input  wire        clk,
    input  wire        reset,

    // ===== 流水线握手 =====
    input  wire        ID_allowin,              // 来自ID级：ID级允许接收新指令
    output wire        IF_to_ID_valid,          // 输出到ID级：IF级有效数据

    // ===== 指令存储器接口 =====
    output wire [31:0] instr_addr,              // 输出到imem：取指地址 (= PC_addr)
    input  wire [31:0] instr,                   // 来自imem：取到的指令

    // ===== 分支跳转信号（来自ID级） =====
    input  wire        Branch_taken,            // 来自ID级：条件分支发生
    input  wire [31:0] Branch_target_addr,      // 来自ID级：分支目标地址
    input  wire        Jal_taken,               // 来自ID级：JAL跳转发生
    input  wire [31:0] Jal_target_addr,         // 来自ID级：JAL目标地址
    input  wire        Jalr_taken,              // 来自ID级：JALR跳转发生
    input  wire [31:0] Jalr_target_addr,        // 来自ID级：JALR目标地址

    // ===== 中断信号（来自CSR模块） =====
    input  wire        global_interrupt_enable, // 来自CSR/pipeline_top：mstatus.MIE
    input  wire [31:0] mie,                     // 来自CSR：中断使能寄存器
    input  wire [31:0] mip,                     // 来自CSR：中断待决寄存器
    input  wire [31:0] mtvec,                   // 来自CSR：中断向量基地址
    input  wire        mret_taken,              // 来自ID级：mret指令发生
    input  wire [31:0] mret_target_addr,        // 来自ID级：mret返回地址 (= mepc)

    // ===== 流水线总线输出 =====
    output wire [63:0] IF_to_ID_bus,            // 输出到ID级：{PC_addr[31:0], instr[31:0]}

    // ===== 中断输出 =====
    output wire        interrupt_taken,         // 输出到ID级/CSR：中断被响应
    output wire [31:0] current_PC               // 输出到CSR：当前PC（保存到mepc）
);
```

**内部子模块实例化：**

| 子模块 | 实例名 | 说明 |
|--------|--------|------|
| `PC` | `U_PC` | 程序计数器，由PCWrite控制更新 |
| `NPC` | `U_NPC` | 下一PC计算，优先级：mret > interrupt > Branch > Jal > Jalr > PC+4 |

**关键内部信号：**
- `PC_addr` [31:0]：当前PC值
- `NPC_addr` [31:0]：下一PC值
- `IF_ready_go` = 1'b1：IF级恒定就绪
- `PCWrite` = IF_ready_go && ID_allowin：PC更新条件
- `ext_interrupt_pending` = mie[11] & mip[11] & global_interrupt_enable：外部中断挂起

---

### 3.2 ID_stage — 译码阶段

```verilog
module ID_stage(
    // ===== 时钟与复位 =====
    input  wire        clk,
    input  wire        reset,

    // ===== 流水线握手（IF→ID） =====
    input  wire        IF_to_ID_valid,          // 来自IF级：IF级数据有效
    input  wire [63:0] IF_to_ID_bus,            // 来自IF级：{PC_addr, instr}
    output wire        ID_allowin,              // 输出到IF级：ID级允许接收

    // ===== 流水线握手（ID→EX） =====
    input  wire        EX_allowin,              // 来自EX级：EX级允许接收
    output wire        ID_to_EX_valid,          // 输出到EX级：ID级数据有效
    output wire [232:0] ID_to_EX_bus,           // 输出到EX级：打包总线（见详解）

    // ===== 写回端口（来自WB级） =====
    input  wire        WB_RF_write_enable,      // 来自WB级：寄存器写使能
    input  wire [4:0]  WB_RF_write_addr,        // 来自WB级：寄存器写地址(rd)
    input  wire [31:0] WB_RF_write_data,        // 来自WB级：寄存器写数据

    // ===== 分支跳转信号输出（到IF级） =====
    output wire        Branch_taken,            // 到IF级：条件分支发生
    output wire [31:0] Branch_target_addr,      // 到IF级：分支目标地址
    output wire        Jal_taken,               // 到IF级：JAL跳转发生
    output wire [31:0] Jal_target_addr,         // 到IF级：JAL目标地址
    output wire        Jalr_taken,              // 到IF级：JALR跳转发生
    output wire [31:0] Jalr_target_addr,        // 到IF级：JALR目标地址

    // ===== 数据前递输入（来自EX/MA级和MA/WB级） =====
    input  wire        EXMA_RegWrite,           // 来自MA级：EX/MA流水线寄存器的RegWrite
    input  wire [4:0]  EXMA_rd,                 // 来自MA级：EX/MA流水线寄存器的rd
    input  wire [31:0] EXMA_load_data,          // 来自MA级：EX/MA级的加载/ALU结果
    input  wire        MAWB_RegWrite,           // 来自WB级：MA/WB流水线寄存器的RegWrite
    input  wire [4:0]  MAWB_rd,                 // 来自WB级：MA/WB流水线寄存器的rd
    input  wire [31:0] MAWB_RF_write_data,      // 来自WB级：MA/WB级的写回数据

    // ===== 冒险检测输入（来自EX级和MA级） =====
    input  wire        IDEX_MemRead,            // 来自EX级：ID/EX流水线寄存器的MemRead（load指令）
    input  wire        IDEX_RegWrite,           // 来自EX级：ID/EX流水线寄存器的RegWrite
    input  wire [4:0]  IDEX_rd,                 // 来自EX级：ID/EX流水线寄存器的rd
    input  wire        EXMA_MemRead,            // 来自MA级：EX/MA流水线寄存器的MemRead

    // ===== 中断信号 =====
    input  wire        interrupt_taken,         // 来自IF级：中断被响应（用于冲刷IF/ID）

    // ===== CSR接口 =====
    input  wire [31:0] csr_read_data,           // 来自CSR模块：CSR读数据
    input  wire [31:0] mepc,                    // 来自CSR模块：mepc寄存器值
    output wire        mret_taken,              // 到IF级/CSR：mret指令发生
    output wire [31:0] mret_target_addr,        // 到IF级：mret目标地址 (= mepc)

    // ===== 显示调试接口 =====
    input  wire [4:0]  reg_sel,                 // 来自外部：选择要查看的寄存器号
    output wire [31:0] reg_data                 // 到外部：选中寄存器的数据
);
```

**内部子模块实例化：**

| 子模块 | 实例名 | 说明 |
|--------|--------|------|
| `ctrl` | `u_ctrl` | 控制信号译码（组合逻辑） |
| `RF` | `U_RF` | 寄存器文件（32x32，下降沿写） |
| `EXT` | `U_EXT` | 立即数扩展 |
| `hazard_detect` | `u_hazard_detect` | 冒险检测 |

**关键内部信号：**
- `IF_to_ID_bus_reg`：IF/ID流水线寄存器
- `ID_valid`：ID级有效位
- `stall`：冒险检测输出的阻塞信号
- `FLUSH_IFID`：冲刷IF/ID寄存器信号
- `ID_ready_go` = ~stall：ID级就绪条件
- `opcode` [6:0] = instr[6:0]
- `funct7` [6:0] = instr[31:25]
- `funct3` [2:0] = instr[14:12]
- `rs1` [4:0] = instr[19:15]
- `rs2` [4:0] = instr[24:20]
- `rd` [4:0] = instr[11:7]
- `RD1` [31:0]：寄存器读端口1数据
- `RD2` [31:0]：寄存器读端口2数据
- `immout` [31:0]：扩展后的立即数
- `ForwardA_reg` [1:0]、`ForwardB_reg` [1:0]：ID级分支/jalr使用的前递选择
- `forward_RD1` [31:0]、`forward_RD2` [31:0]：前递后的操作数
- `is_branch_type`：指令为B型分支
- `is_jalr`：指令为JALR
- `is_csr`：指令为CSR操作（csrrw/csrrs/csrrc）
- `is_mret`：指令为MRET
- `csr_we`：CSR写使能
- `csr_addr` [11:0]：CSR地址 = instr[31:20]
- `csr_write_data` [31:0]：CSR写数据（根据CSRType选择：csrrw→rs1, csrrs→CSR|rs1, csrrc→CSR&~rs1）

---

### 3.3 EX_stage — 执行阶段

```verilog
module EX_stage(
    // ===== 时钟与复位 =====
    input  wire        clk,
    input  wire        reset,

    // ===== 流水线握手（ID→EX） =====
    input  wire        ID_to_EX_valid,          // 来自ID级：ID级数据有效
    input  wire [232:0] ID_to_EX_bus,           // 来自ID级：打包总线
    output wire        EX_allowin,              // 输出到ID级：EX级允许接收

    // ===== 流水线握手（EX→MA） =====
    input  wire        MA_allowin,              // 来自MA级：MA级允许接收
    output wire        EX_to_MA_valid,          // 输出到MA级：EX级数据有效
    output wire [152:0] EX_to_MA_bus,           // 输出到MA级：打包总线

    // ===== 数据前递输入 =====
    input  wire        EXMA_RegWrite,           // 来自MA级：EX/MA的RegWrite
    input  wire [4:0]  EXMA_rd,                 // 来自MA级：EX/MA的rd
    input  wire [31:0] EXMA_load_data,          // 来自MA级：EX/MA的加载/ALU结果
    input  wire        MAWB_RegWrite,           // 来自WB级：MA/WB的RegWrite
    input  wire [4:0]  MAWB_rd,                 // 来自WB级：MA/WB的rd
    input  wire [31:0] MAWB_RF_write_data,      // 来自WB级：MA/WB的写回数据

    // ===== 冒险检测输出（到ID级） =====
    output wire        IDEX_MemRead,            // 到ID级：ID/EX的MemRead
    output wire        IDEX_RegWrite,           // 到ID级：ID/EX的RegWrite
    output wire [4:0]  IDEX_rd                  // 到ID级：ID/EX的rd
);
```

**内部子模块实例化：**

| 子模块 | 实例名 | 说明 |
|--------|--------|------|
| `forwarding` | `U_forwarding` | EX级前递逻辑 |
| `alu` | `ALU` | 算术逻辑单元 |

**关键内部信号：**
- `ID_to_EX_bus_reg`：ID/EX流水线寄存器
- `EX_valid`：EX级有效位
- `EX_ready_go` = 1'b1：EX级恒定就绪
- 从总线解包的信号：
  - `PC_addr` [31:0]：PC值
  - `EX_PC_plus_4` [31:0]：PC+4
  - `EX_rs1` [4:0]、`EX_rs2` [4:0]：源寄存器号
  - `RD1` [31:0]、`RD2` [31:0]：寄存器读数据
  - `EX_immout` [31:0]：立即数
  - `ALUOp` [3:0]：ALU操作码
  - `ALUSrc1`、`ALUSrc2`：ALU输入选择
  - `EX_MemWrite`：存储器写使能
  - `EX_DMType` [2:0]：数据存储器访问类型
  - `EX_MemtoReg` [1:0]：写回数据选择
  - `EX_RegWrite`：寄存器写使能
  - `EX_rd` [4:0]：目标寄存器号
  - `EX_csr_we`：CSR写使能
  - `EX_csr_addr` [11:0]：CSR地址
  - `EX_csr_write_data` [31:0]：CSR写数据
- `ForwardA` [1:0]、`ForwardB` [1:0]：前递选择信号
- `forward_RD1` [31:0]、`forward_RD2` [31:0]：前递后的操作数
- `A` [31:0]：ALU输入A（forward_RD1 或 PC_addr，由ALUSrc1选择）
- `B` [31:0]：ALU输入B（forward_RD2 或 immout，由ALUSrc2选择）
- `aluout` [31:0]：ALU运算结果

---

### 3.4 MA_stage — 访存阶段

```verilog
module MA_stage(
    // ===== 时钟与复位 =====
    input  wire        clk,
    input  wire        reset,

    // ===== 流水线握手（EX→MA） =====
    input  wire        EX_to_MA_valid,          // 来自EX级：EX级数据有效
    input  wire [152:0] EX_to_MA_bus,           // 来自EX级：打包总线
    output wire        MA_allowin,              // 输出到EX级：MA级允许接收

    // ===== 流水线握手（MA→WB） =====
    input  wire        WB_allowin,              // 来自WB级：WB级允许接收
    output wire        MA_to_WB_valid,          // 输出到WB级：MA级数据有效
    output wire [103:0] MA_to_WB_bus,           // 输出到WB级：打包总线

    // ===== 数据存储器接口（到外部DMEM） =====
    output wire        DM_write_enable,         // 到DMEM：写使能
    output wire        DM_read_enable,          // 到DMEM：读使能
    output wire [2:0]  DMType,                  // 到DMEM：访问类型（字节/半字/字）
    output wire [31:0] DM_write_addr,           // 到DMEM：地址
    output wire [31:0] DM_write_data,           // 到DMEM：写数据
    input  wire [31:0] DM_read_data,            // 来自DMEM：读数据

    // ===== 数据前递输出（到ID级和EX级） =====
    output wire        EXMA_RegWrite,           // 到ID/EX级：EX/MA的RegWrite
    output wire [4:0]  EXMA_rd,                 // 到ID/EX级：EX/MA的rd
    output wire [31:0] EXMA_load_data,          // 到ID/EX级：EX/MA的前递数据

    // ===== 冒险检测输出（到ID级） =====
    output wire        EXMA_MemRead,            // 到ID级：EX/MA的MemRead

    // ===== CSR写回（到CSR模块） =====
    output wire        MA_csr_we,               // 到CSR模块：CSR写使能
    output wire [11:0] MA_csr_addr,             // 到CSR模块：CSR地址
    output wire [31:0] MA_csr_write_data        // 到CSR模块：CSR写数据
);
```

**关键内部信号：**
- `EX_to_MA_bus_reg`：EX/MA流水线寄存器
- `MA_valid`：MA级有效位
- `MA_ready_go` = 1'b1：MA级恒定就绪
- 从总线解包的信号：
  - `MA_aluout` [31:0]：ALU结果
  - `DM_write_data` [31:0]：存储器写数据（= forward_RD2）
  - `MA_PC_plus_4` [31:0]：PC+4
  - `MA_MemWrite`：存储器写使能
  - `MA_DMType` [2:0]：数据存储器类型
  - `MA_MemtoReg` [1:0]：写回选择
  - `MA_RegWrite`：寄存器写使能
  - `MA_rd` [4:0]：目标寄存器号
  - `MA_csr_we`：CSR写使能
  - `MA_csr_addr` [11:0]：CSR地址
  - `MA_csr_write_data` [31:0]：CSR写数据
- `is_csr_access`：CSR地址高4位为F时的特殊访问检测

**EXMA_load_data 选择逻辑：**
- 当 `MA_MemtoReg == MemtoReg_MEM` 时：`EXMA_load_data = DM_read_data`（Load指令）
- 否则：`EXMA_load_data = MA_aluout`（ALU指令）

---

### 3.5 WB_stage — 写回阶段

```verilog
module WB_stage(
    // ===== 时钟与复位 =====
    input  wire        clk,
    input  wire        reset,

    // ===== 流水线握手（MA→WB） =====
    input  wire        MA_to_WB_valid,          // 来自MA级：MA级数据有效
    input  wire [103:0] MA_to_WB_bus,           // 来自MA级：打包总线
    output wire        WB_allowin,              // 输出到MA级：WB级允许接收

    // ===== 寄存器写回端口（到ID级的RF） =====
    output wire        RF_write_enable_out,     // 到RF：寄存器写使能
    output wire [4:0]  RF_write_addr_out,       // 到RF：寄存器写地址(rd)
    output wire [31:0] RF_write_data_out,       // 到RF：寄存器写数据

    // ===== 数据前递输出（到ID级和EX级） =====
    output wire        MAWB_RegWrite,           // 到ID/EX级：MA/WB的RegWrite
    output wire [4:0]  MAWB_rd,                 // 到ID/EX级：MA/WB的rd
    output wire [31:0] MAWB_RF_write_data       // 到ID/EX级：MA/WB的写回数据
);
```

**关键内部信号：**
- `MA_to_WB_bus_reg`：MA/WB流水线寄存器
- `WB_valid`：WB级有效位
- `WB_ready_go` = 1'b1：WB级恒定就绪
- 从总线解包的信号：
  - `WB_aluout` [31:0]：ALU结果
  - `WB_DM_read_data` [31:0]：数据存储器读出
  - `WB_PC_plus_4` [31:0]：PC+4
  - `WB_MemtoReg` [1:0]：写回选择
  - `WB_RegWrite`：寄存器写使能
  - `WB_rd` [4:0]：目标寄存器号

**RF_write_data_out 选择逻辑：**
- `MemtoReg == MemtoReg_MEM` → `RF_write_data_out = WB_DM_read_data`（Load指令）
- `MemtoReg == MemtoReg_PC4` → `RF_write_data_out = WB_PC_plus_4`（JAL/JALR）
- 否则 → `RF_write_data_out = WB_aluout`（ALU指令）

---

### 3.6 csr_regs — CSR寄存器组

```verilog
module csr_regs(
    // ===== 时钟与复位 =====
    input  wire        clk,
    input  wire        reset,

    // ===== 外部中断 =====
    input  wire        ext_interrupt,           // 来自外部外设的中断请求

    // ===== CSR写端口（来自MA级） =====
    input  wire        csr_we,                  // 来自MA级：CSR写使能
    input  wire [11:0] csr_addr,                // 来自MA级：CSR地址
    input  wire [31:0] csr_write_data,          // 来自MA级：CSR写数据

    // ===== 中断控制信号（来自IF级） =====
    input  wire        interrupt_taken,         // 来自IF级：中断被响应
    input  wire [31:0] current_PC,              // 来自IF级：被中断的PC
    input  wire        mret_taken,              // 来自ID级：mret指令

    // ===== CSR寄存器输出 =====
    output wire [31:0] mtvec,                   // 到IF级：中断向量基地址
    output wire [31:0] mie,                     // 到IF级：中断使能
    output wire [31:0] mip,                     // 到IF级：中断待决
    output wire [31:0] mstatus,                 // 到pipeline_top：机器状态
    output wire [31:0] mcause,                  // 中断原因
    output wire [31:0] mepc,                    // 到ID级：中断返回地址

    // ===== CSR读数据 =====
    output wire [31:0] csr_read_data            // 到ID级：CSR读数据
);
```

**CSR寄存器列表：**

| 寄存器 | 地址 | 读/写 | 说明 |
|--------|------|-------|------|
| `mstatus` | 0x300 | RW | 机器状态寄存器（MIE位、MPIE位） |
| `mie` | 0x304 | RW | 中断使能寄存器（MEIE位=bit[11]） |
| `mip` | 0x344 | RO(RW) | 中断待决寄存器（MEIP位=bit[11]，由ext_interrupt驱动） |
| `mtvec` | 0x305 | RW | 中断向量基地址 |
| `mepc` | 0x341 | RW | 中断返回地址（中断时自动保存current_PC） |
| `mcause` | 0x342 | RW | 中断原因（中断时自动设置为{1'b1, 31'd11}） |

**中断时自动操作：**
- `mepc` ← `current_PC`
- `mcause` ← `{1'b1, 31'd11}`（外部中断原因码）
- `mstatus.MPIE` ← `mstatus.MIE`
- `mstatus.MIE` ← 0（关全局中断）

**mret时自动操作：**
- `mstatus.MIE` ← `mstatus.MPIE`
- `mstatus.MPIE` ← 1

---

### 3.7 hazard_detect — 冒险检测

```verilog
module hazard_detect(
    // ===== 来自ID级（IF/ID流水线寄存器） =====
    input  wire [4:0]  IFID_rs1,                // 来自ID级：IF/ID的rs1
    input  wire [4:0]  IFID_rs2,                // 来自ID级：IF/ID的rs2
    input  wire        IFID_is_branch_jalr,     // 来自ID级：当前指令是分支或JALR
    input  wire        IFID_is_csr,             // 来自ID级：当前指令是CSR操作

    // ===== 来自EX级（ID/EX流水线寄存器） =====
    input  wire        IDEX_MemRead,            // 来自EX级：ID/EX的MemRead（load指令）
    input  wire        IDEX_RegWrite,           // 来自EX级：ID/EX的RegWrite
    input  wire [4:0]  IDEX_rd,                 // 来自EX级：ID/EX的rd

    // ===== 来自MA级（EX/MA流水线寄存器） =====
    input  wire        EXMA_MemRead,            // 来自MA级：EX/MA的MemRead
    input  wire [4:0]  EXMA_rd,                 // 来自MA级：EX/MA的rd

    // ===== 跳转信号（用于冲刷判断） =====
    input  wire        Branch_taken,            // 来自ID级：分支发生
    input  wire        Jal_taken,               // 来自ID级：JAL发生
    input  wire        Jalr_taken,              // 来自ID级：JALR发生
    input  wire        interrupt_taken,         // 来自IF级：中断发生
    input  wire        mret_taken,              // 来自ID级：mret发生

    // ===== 输出 =====
    output wire        stall,                   // 到ID级：阻塞信号
    output wire        FLUSH_IFID               // 到ID级：冲刷IF/ID寄存器
);
```

**冒险检测条件：**

| 冒险类型 | 条件 | 描述 |
|---------|------|------|
| `load_use_stall` | IDEX_MemRead && IDEX_rd!=0 && (IDEX_rd==rs1 \|\| IDEX_rd==rs2) | Load-Use冒险：EX级是load，ID级使用其结果 |
| `alu_branch_jalr_stall` | IFID_is_branch_jalr && IDEX_RegWrite && IDEX_rd!=0 && (IDEX_rd==rs1 \|\| IDEX_rd==rs2) | ALU-Branch冒险：EX级是ALU，ID级是分支/jalr |
| `load_branch_jalr_stall` | IFID_is_branch_jalr && EXMA_MemRead && EXMA_rd!=0 && (EXMA_rd==rs1 \|\| EXMA_rd==rs2) | Load-Branch冒险：MA级是load，ID级是分支/jalr |
| `alu_csr_stall` | IFID_is_csr && IDEX_RegWrite && IDEX_rd!=0 && IDEX_rd==rs1 | ALU-CSR冒险：EX级是ALU，ID级是CSR |

- `stall` = 以上四种冒险任一发生
- `FLUSH_IFID` = !stall && (Branch_taken \|\| Jal_taken \|\| Jalr_taken \|\| mret_taken \|\| interrupt_taken)

---

### 3.8 forwarding — 数据前递（EX级使用）

```verilog
module forwarding(
    input  wire        clk,
    input  wire        reset,

    // ===== EX级源操作数 =====
    input  wire [4:0]  EX_rs1,                  // 来自EX级：ID/EX的rs1
    input  wire [4:0]  EX_rs2,                  // 来自EX级：ID/EX的rs2

    // ===== EX/MA前递源 =====
    input  wire        EXMA_RegWrite,           // 来自MA级：EX/MA的RegWrite
    input  wire [4:0]  EXMA_rd,                 // 来自MA级：EX/MA的rd

    // ===== MA/WB前递源 =====
    input  wire        MAWB_RegWrite,           // 来自WB级：MA/WB的RegWrite
    input  wire [4:0]  MAWB_rd,                 // 来自WB级：MA/WB的rd

    // ===== 前递选择输出 =====
    output wire [1:0]  ForwardA,                // 到EX级：ALU输入A的前递选择
    output wire [1:0]  ForwardB                 // 到EX级：ALU输入B的前递选择
);
```

**前递选择编码：**

| Forward值 | 含义 | 数据来源 |
|-----------|------|---------|
| `Forward_NONE` (2'b00) | 无前递 | 使用寄存器文件读出的原始数据 |
| `Forward_EXMA` (2'b01) | 从EX/MA级前递 | EXMA_load_data |
| `Forward_MAWB` (2'b10) | 从MA/WB级前递 | MAWB_RF_write_data |

**优先级：** EXMA > MAWB（近的优先）

---

### 3.9 PC — 程序计数器

```verilog
module PC(
    input  wire        clk,
    input  wire        reset,
    input  wire        PCWrite,                 // 来自IF级：PC更新使能
    input  wire [31:0] NPC_addr,                // 来自NPC：下一PC值
    output reg  [31:0] PC_addr                  // 到IF级/NPC/imem：当前PC值
);
```

---

### 3.10 NPC — 下一地址计算

```verilog
module NPC(
    input  wire [31:0] PC_addr,                 // 来自PC：当前PC
    input  wire        Branch_taken,            // 来自ID级
    input  wire [31:0] Branch_target_addr,      // 来自ID级
    input  wire        Jal_taken,               // 来自ID级
    input  wire [31:0] Jal_target_addr,         // 来自ID级
    input  wire        Jalr_taken,              // 来自ID级
    input  wire [31:0] Jalr_target_addr,        // 来自ID级
    input  wire        interrupt_taken,         // 来自IF级
    input  wire [31:0] mtvec_addr,              // 来自CSR：中断向量地址
    input  wire        mret_taken,              // 来自ID级
    input  wire [31:0] mret_target_addr,        // 来自ID级：mepc
    output wire [31:0] NPC_addr                 // 到PC：下一PC值
);
```

**NPC优先级选择：**
```
mret_taken      → mret_target_addr (mepc)
interrupt_taken → mtvec_addr
Branch_taken    → Branch_target_addr
Jal_taken       → Jal_target_addr
Jalr_taken      → Jalr_target_addr
default         → PC_addr + 4
```

---

### 3.11 RF — 寄存器文件

```verilog
module RF(
    input  wire        clk,
    input  wire        reset,
    input  wire        RFWrite,                 // 来自WB级：写使能
    input  wire [4:0]  rs1,                     // 来自ID级：读地址1
    input  wire [4:0]  rs2,                     // 来自ID级：读地址2
    input  wire [4:0]  rd,                      // 来自WB级：写地址
    input  wire [31:0] WriteData,               // 来自WB级：写数据
    output wire [31:0] RD1,                     // 到ID级：读数据1
    output wire [31:0] RD2                      // 到ID级：读数据2
);
```

- 32个32位寄存器，x0恒为0
- 读操作：组合逻辑（assign）
- 写操作：**下降沿**触发（negedge clk）

---

### 3.12 EXT — 立即数扩展

```verilog
module EXT(
    input  wire [4:0]  iimm_shamt,             // 来自ID级：shamt字段 instr[24:20]
    input  wire [11:0] iimm,                   // 来自ID级：I-type立即数 instr[31:20]
    input  wire [11:0] simm,                   // 来自ID级：S-type立即数 {instr[31:25], instr[11:7]}
    input  wire [11:0] bimm,                   // 来自ID级：B-type立即数 {instr[31], instr[7], instr[30:25], instr[11:8]}
    input  wire [19:0] uimm,                   // 来自ID级：U-type立即数 instr[31:12]
    input  wire [19:0] jimm,                   // 来自ID级：J-type立即数 {instr[31], instr[19:12], instr[20], instr[30:21]}
    input  wire [2:0]  EXTOp,                  // 来自ctrl：扩展类型选择
    output reg  [31:0] immout                  // 到ID级：扩展后的32位立即数
);
```

---

### 3.13 ctrl — 控制信号生成

```verilog
module ctrl(
    input  wire [6:0]  Op,                     // 来自ID级：opcode = instr[6:0]
    input  wire [6:0]  Funct7,                 // 来自ID级：funct7 = instr[31:25]
    input  wire [2:0]  Funct3,                 // 来自ID级：funct3 = instr[14:12]
    output wire        RegWrite,               // 到ID级：寄存器写使能
    output wire        ALUSrc1,                // 到EX级：ALU输入A选择（0=寄存器, 1=PC）
    output wire        ALUSrc2,                // 到EX级：ALU输入B选择（0=寄存器, 1=立即数）
    output wire        MemWrite,               // 到MA级：存储器写使能
    output wire [2:0]  EXTOp,                  // 到EXT：立即数扩展类型
    output wire [2:0]  BranchOp,               // 到ID级：分支比较类型
    output wire [3:0]  ALUOp,                  // 到ALU：ALU操作码
    output wire [2:0]  DMType,                 // 到MA级：数据存储器访问类型
    output wire [1:0]  MemtoReg                // 到WB级：写回数据选择
);
```

---

### 3.14 alu — 算术逻辑单元

```verilog
module alu(
    input  wire signed [31:0] A,               // 来自EX级：操作数A
    input  wire signed [31:0] B,               // 来自EX级：操作数B
    input  wire [3:0]  ALUOp,                  // 来自ctrl：操作码
    output reg  signed [31:0] C                // 到EX级：运算结果
);
```

---

### 3.15 imem — 指令存储器

```verilog
module imem(
    input  wire [10:0] a,                      // 来自soc_top：地址 (instr_addr[12:2])
    output wire [31:0] spo                     // 到soc_top：指令数据
);
```

- ROM，2048x32位
- 从 `inst.txt` 读取初始化数据
- 组合逻辑读

---

### 3.16 dmem — 数据存储器

```verilog
module dmem(
    input  wire        clk,
    input  wire        DM_write_enable,        // 来自MA级：写使能
    input  wire [2:0]  DM_Type,                // 来自MA级：访问类型
    input  wire [31:0] addr,                   // 来自MA级：地址
    input  wire [31:0] din,                    // 来自MA级：写数据
    output wire [31:0] dout                    // 到MA级：读数据
);
```

- RAM，128x32位
- 同步写（posedge clk），异步读（组合逻辑）
- 支持字节(BYTE/BYTEU)、半字(HALF/HALFU)、字(WORD)读写

---

### 3.17 soc_top — SoC顶层

```verilog
module soc_top(
    input  wire        clk,                    // 系统时钟
    input  wire        rstn,                   // 低有效复位
    input  wire [4:0]  reg_sel,                // 调试：寄存器选择
    output wire [31:0] reg_data                // 调试：寄存器数据
);
```

---

### 3.18 pipeline_top — 流水线顶层

```verilog
module pipeline_top(
    input  wire        clk,
    input  wire        reset,

    // 指令存储器
    output wire [31:0] instr_addr,
    input  wire [31:0] instr,

    // 数据存储器
    output wire        bus_write_enable,
    output wire        bus_read_enable,
    output wire [31:0] bus_write_addr,
    output wire [31:0] bus_write_data,
    output wire [2:0]  bus_DM_Type,
    input  wire [31:0] bus_read_data,

    // 调试
    input  wire [4:0]  reg_sel,
    output wire [31:0] reg_data,

    // 外部中断
    input  wire        ext_interrupt
);
```

---

## 4. 流水线总线内容详解

### 4.1 IF_to_ID_bus [63:0]

```
[63:32] PC_addr    [31:0]  // 取指PC地址
[31:0]  instr      [31:0]  // 取到的32位指令
```

### 4.2 ID_to_EX_bus [232:0]

按拼接顺序（高位在前）：

```
位域              宽度    信号名           说明
─────────────────────────────────────────────────────
[232:201]         32      PC_addr          指令PC地址
[200:169]         32      PC_plus_4        PC+4（用于JAL/JALR写回）
[168:164]          5      rs1              源寄存器1地址
[163:159]          5      rs2              源寄存器2地址
[158:127]         32      RD1              寄存器读数据1（原始值，未前递）
[126:95]          32      RD2              寄存器读数据2（原始值，未前递）
[94:63]           32      immout           扩展后的立即数
[62:59]            4      ALUOp            ALU操作码
[58]               1      ALUSrc1          ALU输入A选择（0=reg, 1=PC）
[57]               1      ALUSrc2          ALU输入B选择（0=reg, 1=imm）
[56]               1      MemWrite         存储器写使能
[55:53]            3      DMType           数据存储器访问类型
[52:51]            2      MemtoReg         写回数据选择
[50]               1      RegWrite         寄存器写使能
[49:45]            5      rd               目标寄存器地址
[44]               1      csr_we           CSR写使能
[43:32]           12      csr_addr         CSR寄存器地址
[31:0]            32      csr_write_data   CSR写数据
```

### 4.3 EX_to_MA_bus [152:0]

```
位域              宽度    信号名           说明
─────────────────────────────────────────────────────
[152:121]         32      aluout           ALU运算结果
[120:89]          32      forward_RD2      前递后的RS2数据（Store指令的写数据）
[88:57]           32      PC_plus_4        PC+4
[56]               1      MemWrite         存储器写使能
[55:53]            3      DMType           数据存储器访问类型
[52:51]            2      MemtoReg         写回数据选择
[50]               1      RegWrite         寄存器写使能
[49:45]            5      rd               目标寄存器地址
[44]               1      csr_we           CSR写使能
[43:32]           12      csr_addr         CSR寄存器地址
[31:0]            32      csr_write_data   CSR写数据
```

### 4.4 MA_to_WB_bus [103:0]

```
位域              宽度    信号名           说明
─────────────────────────────────────────────────────
[103:72]          32      aluout           ALU运算结果
[71:40]           32      DM_read_data     数据存储器读出数据
[39:8]            32      PC_plus_4        PC+4
[7:6]              2      MemtoReg         写回数据选择
[5]                1      RegWrite         寄存器写使能
[4:0]              5      rd               目标寄存器地址
```

---

## 5. 模块间完整连接关系

### 5.1 流水线握手信号连接

```
IF_stage                ID_stage                EX_stage                MA_stage                WB_stage
────────                ────────                ────────                ────────                ────────
IF_to_ID_valid ───────► IF_to_ID_valid
IF_to_ID_bus   ───────► IF_to_ID_bus
               ◄─────── ID_allowin
                         ID_to_EX_valid ───────► ID_to_EX_valid
                         ID_to_EX_bus   ───────► ID_to_EX_bus
                         ◄────────────── EX_allowin
                                          EX_to_MA_valid ───────► EX_to_MA_valid
                                          EX_to_MA_bus   ───────► EX_to_MA_bus
                                          ◄────────────── MA_allowin
                                                           MA_to_WB_valid ───────► MA_to_WB_valid
                                                           MA_to_WB_bus   ───────► MA_to_WB_bus
                                                           ◄────────────── WB_allowin
```

### 5.2 分支跳转信号连接

```
ID_stage                         IF_stage
────────                         ────────
Branch_taken         ──────────► Branch_taken
Branch_target_addr   ──────────► Branch_target_addr
Jal_taken            ──────────► Jal_taken
Jal_target_addr      ──────────► Jal_target_addr
Jalr_taken           ──────────► Jalr_taken
Jalr_target_addr     ──────────► Jalr_target_addr
mret_taken           ──────────► mret_taken
mret_target_addr     ──────────► mret_target_addr
```

### 5.3 写回信号连接

```
WB_stage                         ID_stage (RF)
────────                         ─────────────
RF_write_enable_out  ──────────► WB_RF_write_enable
RF_write_addr_out    ──────────► WB_RF_write_addr
RF_write_data_out    ──────────► WB_RF_write_data
```

### 5.4 数据前递连接

**EX/MA级前递（EXMA_*）— 由 MA_stage 产生：**

```
MA_stage                         ID_stage     EX_stage
────────                         ────────     ────────
EXMA_RegWrite        ──────────► EXMA_RegWrite  EXMA_RegWrite
EXMA_rd              ──────────► EXMA_rd        EXMA_rd
EXMA_load_data       ──────────► EXMA_load_data EXMA_load_data
EXMA_MemRead         ──────────► EXMA_MemRead   (仅ID级用)
```

**MA/WB级前递（MAWB_*）— 由 WB_stage 产生：**

```
WB_stage                         ID_stage     EX_stage
────────                         ────────     ────────
MAWB_RegWrite        ──────────► MAWB_RegWrite  MAWB_RegWrite
MAWB_rd              ──────────► MAWB_rd        MAWB_rd
MAWB_RF_write_data   ──────────► MAWB_RF_write_data MAWB_RF_write_data
```

### 5.5 冒险检测信号连接

```
EX_stage                         ID_stage (hazard_detect)
────────                         ────────────────────────
IDEX_MemRead         ──────────► IDEX_MemRead
IDEX_RegWrite        ──────────► IDEX_RegWrite
IDEX_rd              ──────────► IDEX_rd
```

### 5.6 中断信号连接

```
soc_top                          pipeline_top
────────                         ────────────
ext_interrupt        ──────────► ext_interrupt

pipeline_top内部：
  ext_interrupt ──────────► csr_regs.ext_interrupt

  csr_regs                IF_stage                ID_stage
  ────────                ────────                ────────
  mtvec          ────────┬► mtvec
  mie            ────────┬► mie
  mip            ────────┬► mip
  mstatus.MIE ──► global_interrupt_enable ──► (IF内部判断中断)
  mepc           ────────┬────────────────────► mepc
                          │
  IF_stage                │    ID_stage
  ────────                │    ────────
  interrupt_taken ────────┼──► interrupt_taken
  current_PC      ────────┘    (用于冲刷判断)
                  ──────────► csr_regs.current_PC (保存到mepc)
  mret_taken      ◄─────────── mret_taken (ID级产生)
  mret_target_addr◄─────────── mret_target_addr
```

### 5.7 CSR写回连接

```
MA_stage                         csr_regs
────────                         ────────
MA_csr_we            ──────────► csr_we
MA_csr_addr          ──────────► csr_addr
MA_csr_write_data    ──────────► csr_write_data
```

### 5.8 CSR读取连接

```
csr_regs                         ID_stage
───────                          ────────
csr_read_data        ──────────► csr_read_data   (用于CSR指令读取)
mepc                 ──────────► mepc            (用于mret_target_addr)
```

### 5.9 指令存储器连接（soc_top外部）

```
pipeline_top                     imem
──────────                       ────
instr_addr[12:2]     ──────────► a[10:0]
instr                ◄────────── spo[31:0]
```

### 5.10 数据存储器连接（soc_top外部）

```
MA_stage                         dmem (通过pipeline_top→soc_top)
────────                         ────
DM_write_enable      ──────────► DM_write_enable
DM_read_enable       ──────────► (与DM_write_enable共用读写控制)
DMType               ──────────► DM_Type
DM_write_addr        ──────────► addr
DM_write_data        ──────────► din
DM_read_data         ◄────────── dout
```

---

## 6. 画图参考：信号分组汇总

### 6.1 每个流水级画图时需要标注的信号

#### IF级（画图框标注）

**输入信号：**
- `clk`, `reset`
- `ID_allowin` ← ID级
- `instr[31:0]` ← imem
- `Branch_taken`, `Branch_target_addr[31:0]` ← ID级
- `Jal_taken`, `Jal_target_addr[31:0]` ← ID级
- `Jalr_taken`, `Jalr_target_addr[31:0]` ← ID级
- `global_interrupt_enable` ← CSR(mstatus.MIE)
- `mie[31:0]`, `mip[31:0]`, `mtvec[31:0]` ← CSR
- `mret_taken` ← ID级
- `mret_target_addr[31:0]` ← ID级(=mepc)

**输出信号：**
- `instr_addr[31:0]` → imem
- `IF_to_ID_valid` → ID级
- `IF_to_ID_bus[63:0]` → ID级
- `interrupt_taken` → ID级 + CSR
- `current_PC[31:0]` → CSR

**内部框：** PC → NPC（选择下一PC）→ 输出到imem

---

#### ID级（画图框标注）

**输入信号：**
- `clk`, `reset`
- `IF_to_ID_valid` ← IF级
- `IF_to_ID_bus[63:0]` ← IF级
- `EX_allowin` ← EX级
- `WB_RF_write_enable`, `WB_RF_write_addr[4:0]`, `WB_RF_write_data[31:0]` ← WB级
- `EXMA_RegWrite`, `EXMA_rd[4:0]`, `EXMA_load_data[31:0]` ← MA级(前递)
- `MAWB_RegWrite`, `MAWB_rd[4:0]`, `MAWB_RF_write_data[31:0]` ← WB级(前递)
- `IDEX_MemRead`, `IDEX_RegWrite`, `IDEX_rd[4:0]` ← EX级(冒险检测)
- `EXMA_MemRead` ← MA级(冒险检测)
- `interrupt_taken` ← IF级
- `csr_read_data[31:0]` ← CSR
- `mepc[31:0]` ← CSR
- `reg_sel[4:0]` ← 外部

**输出信号：**
- `ID_allowin` → IF级
- `ID_to_EX_valid` → EX级
- `ID_to_EX_bus[232:0]` → EX级
- `Branch_taken`, `Branch_target_addr[31:0]` → IF级
- `Jal_taken`, `Jal_target_addr[31:0]` → IF级
- `Jalr_taken`, `Jalr_target_addr[31:0]` → IF级
- `mret_taken` → IF级 + CSR
- `mret_target_addr[31:0]` → IF级
- `reg_data[31:0]` → 外部

**内部框：**
- ctrl（译码器）→ 生成控制信号
- RF（寄存器文件）→ 读rs1/rs2
- EXT（立即数扩展）
- hazard_detect（冒险检测）→ stall, FLUSH_IFID
- Branch比较器（用forward_RD1, forward_RD2）
- ID级前递MUX（ForwardA_reg, ForwardB_reg）

---

#### EX级（画图框标注）

**输入信号：**
- `clk`, `reset`
- `ID_to_EX_valid` ← ID级
- `ID_to_EX_bus[232:0]` ← ID级
- `MA_allowin` ← MA级
- `EXMA_RegWrite`, `EXMA_rd[4:0]`, `EXMA_load_data[31:0]` ← MA级(前递)
- `MAWB_RegWrite`, `MAWB_rd[4:0]`, `MAWB_RF_write_data[31:0]` ← WB级(前递)

**输出信号：**
- `EX_allowin` → ID级
- `EX_to_MA_valid` → MA级
- `EX_to_MA_bus[152:0]` → MA级
- `IDEX_MemRead` → ID级(冒险检测)
- `IDEX_RegWrite` → ID级(冒险检测)
- `IDEX_rd[4:0]` → ID级(冒险检测)

**内部框：**
- forwarding模块 → ForwardA, ForwardB
- 前递MUX → forward_RD1, forward_RD2
- ALUSrc1 MUX → A（forward_RD1 或 PC_addr）
- ALUSrc2 MUX → B（forward_RD2 或 immout）
- ALU → aluout

---

#### MA级（画图框标注）

**输入信号：**
- `clk`, `reset`
- `EX_to_MA_valid` ← EX级
- `EX_to_MA_bus[152:0]` ← EX级
- `WB_allowin` ← WB级
- `DM_read_data[31:0]` ← dmem

**输出信号：**
- `MA_allowin` → EX级
- `MA_to_WB_valid` → WB级
- `MA_to_WB_bus[103:0]` → WB级
- `DM_write_enable` → dmem
- `DM_read_enable` → dmem
- `DMType[2:0]` → dmem
- `DM_write_addr[31:0]` → dmem
- `DM_write_data[31:0]` → dmem
- `EXMA_RegWrite` → ID级 + EX级(前递)
- `EXMA_rd[4:0]` → ID级 + EX级(前递)
- `EXMA_load_data[31:0]` → ID级 + EX级(前递)
- `EXMA_MemRead` → ID级(冒险检测)
- `MA_csr_we` → CSR
- `MA_csr_addr[11:0]` → CSR
- `MA_csr_write_data[31:0]` → CSR

**内部框：**
- EXMA_load_data选择MUX（MemtoReg_MEM → DM_read_data, 其他 → aluout）

---

#### WB级（画图框标注）

**输入信号：**
- `clk`, `reset`
- `MA_to_WB_valid` ← MA级
- `MA_to_WB_bus[103:0]` ← MA级

**输出信号：**
- `WB_allowin` → MA级
- `RF_write_enable_out` → ID级(RF)
- `RF_write_addr_out[4:0]` → ID级(RF)
- `RF_write_data_out[31:0]` → ID级(RF)
- `MAWB_RegWrite` → ID级 + EX级(前递)
- `MAWB_rd[4:0]` → ID级 + EX级(前递)
- `MAWB_RF_write_data[31:0]` → ID级 + EX级(前递)

**内部框：**
- 写回数据选择MUX（MemtoReg_MEM → DM_read_data, MemtoReg_PC4 → PC_plus_4, MemtoReg_ALU → aluout）

---

### 6.2 前递数据通路图

```
                    ┌──────────────────────────────────────────────────────┐
                    │              数据前递通路                             │
                    │                                                      │
  MA_stage ────────►│  EXMA_RegWrite, EXMA_rd, EXMA_load_data             │
                    │       │                  │                           │
                    │       ▼                  ▼                           │
                    │  ┌─────────┐      ┌──────────┐                      │
                    │  │ ID级    │      │ EX级     │                      │
                    │  │前递MUX  │      │forwarding│                      │
                    │  │(Branch/ │      │模块+MUX  │                      │
                    │  │ Jalr)   │      │(ALU操作数)│                      │
                    │  └─────────┘      └──────────┘                      │
                    │       ▲                  ▲                           │
                    │       │                  │                           │
  WB_stage ────────►│  MAWB_RegWrite, MAWB_rd, MAWB_RF_write_data        │
                    │                                                      │
                    └──────────────────────────────────────────────────────┘
```

### 6.3 冒险检测信号图

```
  EX_stage ────────► IDEX_MemRead, IDEX_RegWrite, IDEX_rd
        │                         │
        │                         ▼
        │              ┌─────────────────────┐
        │              │   hazard_detect     │
        │              │                     │
  MA_stage ────────►   │  load_use_stall     │──► stall ──► ID级阻塞
  EXMA_MemRead,        │  alu_branch_stall   │              (PCWrite=0,
  EXMA_rd              │  load_branch_stall  │               保持IF/ID不变)
        │              │  alu_csr_stall      │
        │              └─────────────────────┘
        │                         │
  ID_stage ────────►              ▼
  Branch_taken,       ┌─────────────────────┐
  Jal_taken,          │  FLUSH_IFID判断     │──► FLUSH_IFID ──► 清空IF/ID
  Jalr_taken,         │  = !stall &&         │
  interrupt_taken,    │    (跳转信号有效)    │
  mret_taken          └─────────────────────┘
```

### 6.4 中断处理通路

```
  ext_interrupt ──► csr_regs.mip[MEIP]
                        │
  IF_stage:             ▼
  mie[11] & mip[11] & mstatus.MIE ──► ext_interrupt_pending
  ext_interrupt_pending & ID_allowin ──► interrupt_taken
                                            │
                 ┌──────────────────────────┤
                 ▼                          ▼
  NPC: interrupt_taken               csr_regs:
  → NPC_addr = mtvec                 mepc ← current_PC
  → PC跳转到中断入口                 mcause ← {1, 11}
                                     mstatus.MPIE ← MIE
                                     mstatus.MIE ← 0
                 │
                 ▼
  ID_stage: interrupt_taken
  → FLUSH_IFID = 1 (清空IF/ID)
```
