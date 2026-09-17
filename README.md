# rsr-sqrt：基于倒平方根 Newton-Raphson 的定点平方根 RTL

本项目实现无符号定点平方根：输入 `x_in` 为 UQ0.16，输出 `sqrt_out` 为 UQ1.8。核心思路不是直接迭代求 \(\sqrt{x}\)，而是先用 Newton-Raphson 求 \(1/\sqrt{m}\)，再计算 \(m\cdot(1/\sqrt{m})\)。

## 定点格式与数值约定

`UQ I.F` 表示无符号定点数：`I` 为整数位数、`F` 为小数位数，总宽度为 `I+F`。一个整数码 `C` 的实际数值为：

\[
\mathrm{value}=C/2^F
\]

| 信号或数据 | 位宽 | 格式 | 含义 |
|---|---:|---|---|
| `x_in` | 16 | UQ0.16 | 输入 \(x=X/2^{16}\)，范围为 \([0,1)\) |
| `norm_m` | 16 | UQ0.16 | 归一化得到的中间尾数 |
| `m_reg` | 20 | UQ2.18 | Newton 关键通路中的尾数 |
| LUT seed | 6 | UQ2.4 | 初始倒平方根近似值 |
| `r_reg`、`t1_reg`、`t2_reg`、`t3_reg` | 20 | UQ2.18 | Newton 迭代寄存器 |
| `mul_p` | 40 | UQ4.36 | 共享乘法器的完整乘积 |
| `final_product` | 36 | UQ2.34 | \(\sqrt{m}\) 的最终高精度结果 |
| `sqrt_out` | 9 | UQ1.8 | 最终平方根输出 |

因为 \(x=X/2^{16}\)，所以输出码的数学参考值可写为：

\[
\mathrm{sqrt\_out}_{\mathrm{ref}}
=
\operatorname{round\mbox{-}half\mbox{-}up}(\sqrt{x}\cdot2^8)
=
\operatorname{round\mbox{-}half\mbox{-}up}(\sqrt{X})
\]

## 顶层接口

`rtl/sqrt_top.v` 只负责封装 `sqrt_core`，接口保持简单：

| 端口 | 方向 | 说明 |
|---|---|---|
| `clk` | 输入 | 时钟 |
| `rst_n` | 输入 | 异步低有效复位 |
| `start` | 输入 | 在空闲状态发起一次运算 |
| `x_in[15:0]` | 输入 | UQ0.16 输入码 |
| `busy` | 输出 | 运算进行时为 1 |
| `done` | 输出 | 结果有效时输出一个时钟周期的脉冲 |
| `sqrt_out[8:0]` | 输出 | UQ1.8 平方根输出码 |

使用时应只在 `busy=0` 时拉高 `start`。非零输入从 `start` 被采样到 `done=1` 共经过 12 个时钟周期；零输入走快速路径，在下一周期给出 `done` 和结果 `0`。

## 算法流程

### 1. 归一化

对于非零输入，组合逻辑寻找最高的非零二进制位对，并构造：

\[
x=m\cdot2^{-2e}
\]

其中：

\[
m\in[0.25,1),\qquad e\in[0,7]
\]

只使用偶数位左移：`0, 2, 4, ..., 14`。这样平方根的指数恢复为：

\[
\sqrt{x}=\sqrt{m}\cdot2^{-e}
\]

归一化初值 `norm_m` 是 UQ0.16；写入关键通路寄存器时转换为 UQ2.18：

```verilog
m_reg <= {2'b00, norm_m, 2'b00};
```

即保持数值不变，同时让 `m_reg`、`r_reg` 和所有乘法器输入统一为 UQ2.18。

### 2. 24 项 midpoint seed LUT

归一化后的 \(m\) 被分为 24 个等宽区间：

\[
[0.25,0.28125),\ [0.28125,0.3125),\ \ldots,\ [0.96875,1)
\]

地址由：

```verilog
seed_addr = m_reg[17:13] - 5'd8;
```

得到，范围为 `0...23`。每一项按该区间中点生成：

\[
\mathrm{seed}[k]
=
\operatorname{round\mbox{-}half\mbox{-}up}
\left(
\frac{2^4}{\sqrt{(k+8.5)/32}}
\right)
\]

LUT 输出为 6-bit UQ2.4，并通过左移 14 位变为 UQ2.18：

```verilog
seed_q218 = {seed_value, 14'b00000000000000};
```

总 LUT 存储量为：

\[
24\times6=144\text{ bit}
\]

### 3. 两轮倒平方根 Newton-Raphson

迭代公式为：

\[
r_{n+1}
=
\frac{r_n}{2}\left(3-mr_n^2\right)
\]

其中 \(r\approx1/\sqrt{m}\)。项目固定执行两轮迭代。

共享乘法器的两个输入在每个有效状态下均为 UQ2.18，因此：

\[
\mathrm{UQ2.18}\times\mathrm{UQ2.18}
=
\mathrm{UQ4.36}
\]

一轮 Newton 的数据路径如下：

| 步骤 | 运算 | 乘法器结果 | 写回 UQ2.18 的方式 |
|---|---|---|---|
| 1 | \(r^2\) | UQ4.36 | `mul_p[37:18]` |
| 2 | \(m\cdot r^2\) | UQ4.36 | `mul_p[37:18]` |
| 3 | \(3-mr^2\) | UQ2.18 | 直接减法，`3=20'd786432` |
| 4 | \(r(3-mr^2)/2\) | UQ4.36 | `mul_p[38:19]` |

步骤 1、2 的 `[37:18]` 完成 UQ4.36 到 UQ2.18 的截断。步骤 4 比普通 UQ4.36 → UQ2.18 多右移一位，以实现公式中的 `/2`。

`sqrt_core` 的 FSM 顺序为：

```text
IDLE
  -> LOAD_SEED
  -> NR1_SQ -> NR1_MUL_M -> NR1_SUB -> NR1_UPDATE
  -> NR2_SQ -> NR2_MUL_M -> NR2_SUB -> NR2_UPDATE
  -> FINAL_MUL -> FINAL_ROUND -> DONE
```

一个物理 20×20 乘法器 `rtl/mul_unit.v` 在上述所有乘法状态间复用。

### 4. 最终乘法、指数恢复与普通四舍五入

两轮完成后：

\[
\sqrt{m}\approx m\cdot r_2
\]

此时乘法器输出仍是 UQ4.36。归一化范围内 \(m\cdot r\approx\sqrt{m}<2\)，因此 `mul_p[39:38]` 对应的 8 和 4 整数位恒为 0；同时 `m_reg` 来自 UQ0.16 左移两位，其最低两位恒为 0，因此完整乘积最低两位也恒为 0。RTL 通过：

```verilog
final_product <= mul_p[37:2];
```

将 UQ4.36 精确转换为 36-bit UQ2.34；没有丢失有效小数信息。

随后按以下三个清晰步骤完成输出转换：

1. 先按归一化指数恢复数值：`sqrt_x_q234 = final_product >> e`，格式仍按 UQ2.34 解释；
2. 直接取 `sqrt_x_q234[34:26]`，得到截断的 UQ1.8；
3. 查看下一位 `sqrt_x_q234[25]`，该位为 1 时输出加 1，执行非负数的 round-half-up。

## 目录结构

```text
rtl/
  sqrt_top.v                 顶层封装
  sqrt_core.v                归一化、FSM、Newton 数据路径和输出舍入
  seed_lut.v                 24 项 UQ2.4 初始值 LUT
  mul_unit.v                 共享 20×20 无符号乘法器

matlab/
  sqrt_fixed_verify.m        与 RTL 对齐的 bit-accurate 定点模型
  generate_expected_results.m
                              生成独立的精确参考 TXT

sim/
  run_modelsim.do            ModelSim 一键编译和运行脚本
  tb/sqrt_core_tb.sv         65536 向量的 SystemVerilog testbench
  data/rsr_newton_uq218/
    expected_uq18.txt        输入码与精确参考输出码
    rtl_uq18_results.txt     输入、期望、RTL 输出和通过标志
```

## 验证方法

### MATLAB bit-accurate 模型

在仓库根目录执行：

```text
matlab -batch "run('matlab/sqrt_fixed_verify.m')"
```

该脚本会：

1. 生成并打印 24 项 UQ2.4 midpoint seed；
2. 按 RTL 相同的 UQ2.18 数据路径、位段截断、指数恢复和 round-half-up 逐项计算；
3. 穷举全部 65536 个输入，并与 \(\operatorname{round\mbox{-}half\mbox{-}up}(\sqrt{X})\) 比较。

### 独立参考 TXT 生成

```text
matlab -batch "run('matlab/generate_expected_results.m')"
```

该脚本使用整数二分求 \(\lfloor\sqrt{X}\rfloor\) 和整数阈值比较完成普通四舍五入；不调用 RTL，也不使用定点 Newton 模型的输出作为期望值。

### ModelSim RTL 全量验证

```text
cd sim
vsim -c -do run_modelsim.do
```

testbench 对每一个输入发起一次完整的 `start/busy/done` 事务，读取 `expected_uq18.txt`，比对 `sqrt_out`，并写入 `rtl_uq18_results.txt`。

当前全量仿真结果：

```text
65536 vectors checked
0 mismatches
```
