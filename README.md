# MoonFaultGraph 0.5.0

MoonFaultGraph 是一个 MoonBit 静态故障树分析工具。系统设计人员可以导入 Open-PSA MEF XML，检查跨组件、跨故障树的事件引用，计算顶事件概率、重要度和有符号素蕴含项，并导出修改概率后的原结构模型。

## 分析包含多棵树的 MEF

安装 MoonBit 和 Node.js 22，在仓库根目录运行以下命令。

```sh
moon update
moon run cmd/main --target js -- examples/scoped-power-plant-a.json
moon run cmd/main --target js -- examples/scoped-power-plant-b.json
```

两个请求分别选择同一文档里的 `PlantA.Top` 和 `PlantB.Top`，输出概率 0.804 和 0.378。模型包含公开事件 `Grid`、三个各自独立的私有 `Power`，以及嵌套组件 `PlantA.Pump`。第一棵树的 XOR 使用组件内的 NAND 门，第二棵树的 NOR 引用第一棵树的两个事件。 [模型 XML](examples/scoped-power.xml)

在 `examples` 下另建 `scoped-power-export.json`，添加以下请求，运行时按请求文件定位输入与输出。如果输出文件已存在，CLI 会报错并保留原文件。

```json
{
  "mef": "scoped-power.xml",
  "top": "PlantA.Top",
  "prime_implicants": true,
  "probability_overrides": { "PlantA.Power": 0.25 },
  "export": "scoped-power-exported.xml"
}
```

```sh
moon run cmd/main --target js -- examples/scoped-power-export.json
```

将两个原始请求中 `mef` 改为导出的 XML 并重新运行，两个顶事件的概率分别为 0.690 和 0.315。导出保留故障树、组件、角色、门和引用。写入的概率仅覆盖 `PlantA.Power`，第二棵树的变化来自跨树引用。可运行验证脚本自动完成这些步骤。 [往返验证](docs/VALIDATION.md)

## 支持的 MEF 范围

- 一份 XML 可包含多棵 `define-fault-tree`、嵌套 `define-component` 和可选的 `model-data`。
- 公式支持 AND、OR、NOT、XOR、NAND、NOR、`atleast`、事件直连和布尔常量。基础事件使用固定概率，状态事件使用布尔值。
- 支持公开短名、在当前容器下的相对路径和完整限定名。私有角色从最近容器继承，可显式覆盖。不同作用域的私有同名事件各自独立。显式限定路径可引用私有事件。
- `top` 接受公开门名或完整路径。多候选顶事件时需显式选择。概率覆盖接受公开基础事件名或完整路径。
- 静态子集以独立基础变量建模。动态门、概率分布、参数表达式、共因组和外部引用由校验拒绝。资源上限按整个文档计算。 [当前范围](docs/VALIDATION.md)

## 供电方案评审

```sh
moon run cmd/main --target js -- examples/power-design-review.json
```

批量请求 `design_review` 指定统一的结果定义、概率口径和可选目标，对比基准和备选的风险、相对变化和事件预防效果。共用电源基准概率为 0.1540，改善共用电源后为 0.0788，改用独立馈电后为 0.1036。按示例设定的 0.09 上限，改善共用电源的方案达标。案例数值用于复算测试。 [方案输入](examples/power-design-review.json)

对当前方案，设顶事件概率为 `Q`，指定事件置为发生和未发生后概率为 `Q1`、`Q0`。RAW 为 `Q1/Q`，RRW 为 `Q/Q0`，FV/DIF 采用 SCRAM 口径 `p×Q1/Q`。报告也提供 `Q1−Q0` 和零分母状态。有符号素蕴含项保留事件发生与未发生两种条件。 [指标和技术说明](docs/proposal.md)

## 安装与测试

```sh
moon add btlqql/moon_faultgraph@0.5.0
moon test --target js --deny-warn
python scripts/verify.py
```

核心分析 API 为 `btlqql/moon_faultgraph`，MEF API 为 `btlqql/moon_faultgraph/mef`。XML 读写复用 Milky2018/xml，作用域解析、BDD 和风险计算由 MoonBit 实现。 [MoonCakes 版本入口](https://mooncakes.io/docs/btlqql/moon_faultgraph@0.5.0) · [验证说明](docs/VALIDATION.md) · [报名版](docs/proposal-summary.md) · [完整申报书](docs/proposal.md) · [来源与许可](THIRD_PARTY.md)
