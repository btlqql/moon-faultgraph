# MoonFaultGraph 0.4.0

面向冗余供电和服务架构评审的 MoonBit 静态故障树分析工具。导入 Open-PSA MEF，保留共享事件身份，计算顶事件概率、事件重要度与含正负事件的素蕴含项，并导出修改概率后的模型。

## 复现供电与模式切换案例

```sh
moon update
moon run cmd/main --target js -- examples/shared-power-review.json
moon run cmd/main --target js -- examples/independent-power-review.json
moon run cmd/main --target js -- examples/mode-switch-review.json
```

共用上游供电的模型得到顶事件概率 **0.154**。共用电源失效概率从 0.10 降至 0.02 后，结果为 **0.0788**。另建独立馈电模型并采用例中独立性假设，结果为 **0.1036**。这些概率来自可审查的示例参数，供验证分析流程和比较假设。

模式切换案例会输出三个素蕴含项，包含与模式状态无关的“两条路径都失效”。共享基础事件在同一模型中只建一个随机变量。

## 导入、分析、导出

请求文件示例见 `examples/shared-power-review.json`。字段 `mef` 指向输入 XML，`probability_overrides` 按事件名称替换概率，`prime_implicants` 开启完整有符号项，`export` 可指定尚不存在的输出 XML。输入输出路径相对于请求文件。多顶事件时，用 `top` 选择分析对象。

支持范围为一棵平面静态树和可选 `model-data`，含命名公开门、共享基础事件、固定概率、状态常量、AND/OR/NOT 与 `atleast`。不同基础事件采用独立性假设。复杂命名空间、参数表达式、分布、动态门、组件、CCF 组与外部引用由输入校验拒绝。

## 分析定义

令 `Q` 为基准概率，`Q1` 和 `Q0` 分别为强制事件发生和不发生后的概率。RAW 为 `Q1/Q`，RRW 为 `Q/Q0`，FV 采用 SCRAM 的诊断重要度口径 `p×Q1/Q`。基准为零时三个比率均标为 undefined，正分子除以零的 RRW 标为 unbounded。有 NOT 的模型保留 Birnbaum 的符号，使用实际强制情景解释方向。

素蕴含项分析比较 BDD 两个分支及其交集。返回项为足以触发顶事件且删除任一字面量即失效的最小条件。分析资源超限时返回错误。

## 安装和验证

```sh
moon add btlqql/moon_faultgraph@0.4.0
moon test --target js --deny-warn
python scripts/verify.py
```

库核心 API 为 `btlqql/moon_faultgraph`，MEF 解析与导出为 `btlqql/moon_faultgraph/mef`。原 JSON 请求、概率、Birnbaum、正割集、条件和单调区间接口继续可用。XML 词法复用 Milky2018/xml，语义解析、BDD 和风险计算由 MoonBit 实现。

[验证记录](docs/VALIDATION.md) · [生态对照](docs/ECOSYSTEM.md) · [完整申报书](docs/proposal.md) · [一页项目说明](docs/proposal-summary.md)
