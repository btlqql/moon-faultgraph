# MoonFaultGraph 0.5.0 验证说明

## 多树 MEF 的往返验收

`examples/scoped-power.xml` 包含两棵故障树、一个组件、三个同名私有事件和一个全局公开事件。两棵树通过相对引用和完整限定名使用组件或其他树中的事件。验证脚本把 `PlantA.Power` 的概率从 0.10 覆盖为 0.25 后导出，逐节点比较新 XML 的树、组件、角色、门、引用与事件声明。随后重导入同一个导出文件并分别计算两个顶事件。 [案例 XML](../examples/scoped-power.xml) · [对照脚本](../scripts/verify_scram.py)

| 顶事件 | 原模型概率 | 导出后重导入概率 | 带符号素蕴含项 |
| --- | ---: | ---: | ---: |
| `PlantA.Top` | 0.804 | 0.690 | 3 |
| `PlantB.Top` | 0.378 | 0.315 | 1 |

手算中，PlantA 的联锁门为 `NAND(Pump.Power, Grid)`，概率为 `1−0.4×0.3=0.88`。它与 `PlantA.Power` 组成 XOR，输入为 0.10 时结果为 0.804，改为 0.25 后为 0.690。PlantB 的顶事件为三个独立事件的 NOR，结果由 `(1−0.3)×(1−0.10)×(1−0.4)` 变为 `(1−0.3)×(1−0.25)×(1−0.4)`。

## 从源码运行

以下命令在仓库根目录执行。命令行示例需要 Node.js 22。独立校验需要 Python 3。

```sh
moon update
moon test --target js --deny-warn
moon run cmd/main --target js -- examples/scoped-power-plant-a.json
moon run cmd/main --target js -- examples/scoped-power-plant-b.json
python scripts/verify.py
```

独立真值表脚本覆盖 64 组共享变量模型，检查顶事件概率、强制事件概率、重要度和有符号素蕴含项。其中 40 组还核对正割集、单调区间和修复效果。旧 CLI 回归覆盖三种供电方案、模式切换、文件覆盖保护与非法输入。MoonBit 单测另检验顶事件选择、类型错误、跨树循环、重名、结构往返、XML 转义及资源上限。 [真值表验证脚本](../scripts/verify.py) · [MEF 单测](../mef)

## SCRAM 独立对照

参考程序为 SCRAM 0.16.2，源码固定到 `9c9a75ca0c5c2fbb5b4a7d32e29fd25bf90f7bab`。在有 SCRAM 可执行文件和该提交源码的环境运行以下命令，将路径替换为本机实际位置。

```sh
python scripts/verify_scram.py --scram /path/to/scram --reference-model /path/to/scram-source/tests/input/core/ab_bc.xml
```

脚本按顶事件名核对原 XML 和导出 XML 的概率与有符号素蕴含项，同时验证导出结构和限定名。除纯 NOR 的 `PlantB.Top` 外，继续逐项核对 SCRAM 报告中的有限 DIF、RAW、RRW。纯 NOR 分别枚举变量状态，检验 MoonFaultGraph 的强制状态结果，并在报告中记录两个引擎的差异。命令生成 `_build/scram-comparison.json`。分母为零的比率状态由 MoonFaultGraph 单测验证。 [SCRAM 固定版本](https://github.com/rakhimov/scram/tree/9c9a75ca0c5c2fbb5b4a7d32e29fd25bf90f7bab) · [CI 配置](../.github/workflows/ci.yml) · [对照附件入口](https://github.com/btlqql/moon-faultgraph/releases/download/v0.5.0/scram-comparison.json)

## 范围与上限

互操作覆盖固定概率、公开或限定名引用的静态 MEF 子集。每份输入最多 200 万编码单元、12,000 个 XML 元素，解析栈上限为 96 层。最多登记 1,024 个组件、1,024 个事件或门定义、128 个基础事件，并受 4,096 个编译门的上限约束。动态门、参数表达式、概率分布、共因组和外部引用不在当前范围内。 [MEF 实现](../mef)
