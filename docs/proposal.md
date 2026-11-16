# MoonFaultGraph 完整项目申报书

**0.5.0 · 多树静态故障树互操作与方案评审**

| 项目 | 内容 |
| --- | --- |
| 参赛账号 | btlqql |
| 核心技术 | MoonBit、二元决策图、Open-PSA MEF |
| 交付形式 | MoonBit 库、JSON 命令行工具、MEF 示例和自动化验证脚本 |
| 开源许可证 | Apache-2.0 |

[GitHub 仓库](https://github.com/btlqql/moon-faultgraph) · [v0.5.0 附件入口](https://github.com/btlqql/moon-faultgraph/releases/tag/v0.5.0) · [MoonCakes 版本入口](https://mooncakes.io/docs/btlqql/moon_faultgraph@0.5.0)

## 一、项目摘要与实际需求

供电和联锁评审经常从多个团队维护的设备模型开始。同一份交换文档可以有多棵树，每棵树下还会有组件。例如，不同设备都可能定义名为 `Power` 的基础事件，同时又引用一项全局共享事件。分析前需要同时核对事件的身份、组件内部的逻辑和树间依赖，修改概率后还要能把保留原结构的文档交给其他团队复算。

MoonFaultGraph 导入 Open-PSA MEF 静态故障树，从原文档中选择顶事件，计算概率、重要度及有符号素蕴含项。评审者可以按名称调整基础事件的概率，导出保留结构的 XML，再用本工具或 SCRAM 分别检查两个顶事件。另有批量评审入口，以相同结果定义和概率口径比较供电方案。

## 二、复审反馈落实

| 复审反馈 | 0.5.0 的实现与证明 |
| --- | --- |
| 申报书稍长 | 报名表使用精简 Markdown，集中呈现用途、改动与可复验结果。 [报名版](proposal-summary.md) |
| MEF 只覆盖单棵平面静态树 | 同一文档支持多棵 `define-fault-tree`、嵌套 `define-component` 和 `model-data`。导出时保留完整文档，往返脚本重新选择两棵树的顶事件。 |
| 缺少异或等静态门 | 支持二元 XOR 和多输入 NAND、NOR，继续支持 AND、OR、NOT、`atleast`、事件直连和布尔常量。导出保留原门标签。 |
| 缺少组件层级和限定名引用 | 支持公开短名、当前容器的相对路径和完整限定名。角色声明可继承或覆盖，同名私有事件以不同路径表示。 |
| 提交往返验证 | 比较原文档与导出的 XML 结构、角色、门和引用。分别对两个顶事件检查概率、有符号素蕴含项和有限重要度。 [验证说明](VALIDATION.md) |

## 三、导入、分析与导出的实现

导入分两步。先按故障树和组件路径登记定义、角色及公开名，再绑定公式中的引用。解析时先查当前容器下的相对路径。未命中时，短名查公开定义，点分名称查完整路径。私有事件可以通过明确的限定路径引用。已解析的重复引用使用同一布尔变量，不同组件的私有同名事件各自建模。引用类型不符、循环、重名、缺少顶事件选择等情况会返回错误。 [MEF 代码](../mef) · [Open-PSA 静态故障树规范](https://open-psa.github.io/mef/mef/fault_tree_layer.html)

MoonBit 将逻辑编译为约简有序二元决策图（BDD），在各事件给定独立固定概率时逐节点计算顶事件。XOR、NAND 和 NOR 复用布尔运算编译，保留逻辑上的非单调关系。素蕴含项表示足以触发顶事件且不能再去掉条件的最小组合，可同时包含某个事件发生和未发生。强制一个事件发生与未发生得到 Q₁ 和 Q₀，可计算 Birnbaum、FV/DIF、RAW、RRW，以及事件预防后的绝对概率变化。 [BDD 源码](../bdd.mbt) · [素蕴含项源码](../prime.mbt) · [重要度源码](../importance.mbt)

导出根据基础事件的声明路径查找概率，因此覆盖 `PlantA.Power` 不会误改 `PlantA.Pump.Power` 或 `PlantB.Power`。原有树、组件、角色和引用仍保留在导出的文档中。同一个导出文件可用不同 `top` 请求重新分析。XML 读写复用 Milky2018/xml，作用域解析、BDD 与风险计算由 MoonBit 完成。 [来源与许可证](../THIRD_PARTY.md)

## 四、双树案例与计算结果

示例包含 PlantA、PlantB 两棵树，PlantA 下有私有组件 Pump。两棵树合计定义三个私有 `Power`，其初始值为 0.10、0.40、0.30。全局公开事件 `Grid` 的概率为 0.30。PlantA 的顶事件使用相对名 `Pump.Interlock`，PlantB 的顶事件使用绝对限定名 `PlantA.Power` 和 `PlantA.Pump.Power`。 [案例 XML](../examples/scoped-power.xml)

PlantA 的组件 NAND 门概率为 `1−0.40×0.30=0.88`。顶事件使用 XOR，代入 PlantA.Power 的取值 `p` 后概率为 `p×(1−0.88)+(1−p)×0.88`。PlantB 的顶事件为三个独立事件的 NOR，概率为 `(1−0.30)×(1−p)×(1−0.40)`。假定的概率只用于示例演算。

| 顶事件 | 覆盖前 | 仅将 PlantA.Power 改为 0.25 后重导入 | 素蕴含项数量 |
| --- | ---: | ---: | ---: |
| `PlantA.Top` | 0.804 | 0.690 | 3 |
| `PlantB.Top` | 0.378 | 0.315 | 1 |

第二棵树的结果随之变化，证明它确实绑定了第一棵树的事件。三个同名事件在导出 XML 中仍各自对应一个定义，其他概率保持案例设定。概率方向由示例中的 XOR 和 NOR 逻辑决定。 [案例与计算复现](VALIDATION.md)

## 五、验收与复现方式

安装 MoonBit、Node.js 22 与 Python 3 后，从仓库根目录运行。工作目录中生成 JSON 报告和临时验证产物。

```sh
moon update
moon test --target js --deny-warn
moon run cmd/main --target js -- examples/scoped-power-plant-a.json
moon run cmd/main --target js -- examples/scoped-power-plant-b.json
python scripts/verify.py
```

Windows 本地的 MoonBit 测试在 JavaScript、Wasm 和 Wasm GC 各通过 18 项。新测例覆盖 XOR/NAND/NOR 原标签往返、跨树循环、同名与错误路径、类型检查、XML 转义及资源上限。独立真值表脚本检查 64 组共享变量模型，其中 40 组也用于最小割集、区间及修复回归。原有供电评审样例保留，仍可对比 0.1540、0.0788 和 0.1036。 [自动验证说明](VALIDATION.md) · [旧评审请求](../examples/power-design-review.json)

SCRAM 对照使用固定版本 0.16.2。脚本对比原 XML 和导出 XML 的结构，并逐顶事件核对概率和有符号素蕴含项。对纯 NOR 的 `PlantB.Top`，MoonFaultGraph 的强制发生与强制不发生结果由独立真值表核验。SCRAM 在该顶事件报告的部分重要度与强制状态口径有差异，报告保留两套数值。其余案例继续对照 SCRAM 报告中的有限 DIF、RAW、RRW。 [对照脚本](../scripts/verify_scram.py) · [SCRAM 对照附件](https://github.com/btlqql/moon-faultgraph/releases/download/v0.5.0/scram-comparison.json)

## 六、适用边界与交付入口

互操作范围为静态 MEF 子集，支持固定概率以及共享或独立的基础事件。现阶段的输入边界包括动态门、参数概率表达式、概率分布、共因失效组和外部引用。程序按文档限制 XML 深度、组件、定义、事件与编译门数量。实际评审需依据设备数据和任务周期校准模型。 [当前支持范围](../README.md) · [技术验证及限制](VALIDATION.md)

提交材料包含版本源代码、运行命令、两树输入、结构往返检查与数值对照。GitHub 标签记录和 MoonCakes 包对应申报版本。 [GitHub 版本](https://github.com/btlqql/moon-faultgraph/releases/tag/v0.5.0) · [版本提交历史](https://github.com/btlqql/moon-faultgraph/commits/v0.5.0/) · [MoonCakes 模块入口](https://mooncakes.io/docs/btlqql/moon_faultgraph@0.5.0)
