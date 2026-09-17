# RTL 全量仿真

在本目录执行以下命令，即可用 ModelSim 编译 RTL、运行全部 65536 个输入并自动比对：

```text
vsim -c -do run_modelsim.do
```

`tb/sqrt_core_tb.sv` 通过 `sqrt_top` 的 `start/busy/done` 接口，依次驱动所有 UQ0.16 输入码。

算法专属数据目录为 `data/rsr_newton_uq218/`：

- `expected_uq18.txt`：独立生成的精确参考值，每行格式为 `输入码 期望输出码`。
- `rtl_uq18_results.txt`：testbench 每次仿真覆盖生成，每行格式为 `输入码 期望值 RTL输出值 通过标志`；通过标志为 `1` 表示该向量比对通过。

若需要从仓库根目录重新生成参考向量，执行：

```text
matlab -batch "run('matlab/generate_expected_results.m')"
```
