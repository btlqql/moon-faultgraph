# MoonFaultGraph 项目申报书

**MoonFaultGraph 0.4.1 · 静态故障树互操作与供电方案评审**

参赛账号 btlqql，主要实现语言 MoonBit，代码许可证 Apache-2.0。 [GitHub 仓库](https://github.com/btlqql/moon-faultgraph) · [MoonCakes](https://mooncakes.io/docs/btlqql/moon_faultgraph@0.4.1)

## 实际任务

系统设计人员在评审冗余供电时，需要检查两条转换路径是否共享上游电源，并决定哪些方案值得进入后续评估。本工具读入静态 MEF 模型，在同一个请求中比较共用供电基准、改善共用电源和改用独立馈电。结果保留共同故障定义和概率口径，列出概率排序、较基准的变化、是否达到设定目标及每个方案的事件预防效果。单模型请求可将调整后的模型导出供其他工具检查。

## 对应初审的本轮增量

| 审核关注点 | 本轮实现 |
|---|---|
| 常见重要度 | 输出 FV/DIF、RAW、RRW、Birnbaum 与强制发生/不发生情景概率。对零分母输出状态，便于程序可靠读取。 |
| 非单调模型 | 以带符号字面量表示素蕴含项。对 BDD 的两个余因子及其交集求项，去除被包含的项，以发现跨分支的最小故障条件。 |
| 模型交换 | 解析 Open-PSA MEF 静态 XML 子集，对命名门、共享基础事件、固定概率、状态常量和投票门建立语义模型。支持按名称修改概率和重新导出。 |
| 实际评审流程 | 在一份请求中复核不同结构和参数变更。列出预防事件后概率会降低、增加或不变，保留原模型与共同假设。 |

设基准概率为 Q、强制事件发生和不发生后的概率为 Q1 和 Q0。RAW 计算 Q1/Q，RRW 计算 Q/Q0，FV 采用 SCRAM 的 DIF 定义 p×Q1/Q。非单调模型中，Birnbaum 可能为负，应结合两个强制情景解释其方向。 [SCRAM 定义](https://github.com/rakhimov/scram/blob/develop/doc/theory.rst#importance-analysis)

## 运行案例

```sh
moon update
moon run cmd/main --target js -- examples/power-design-review.json
moon run cmd/main --target js -- examples/mode-switch-review.json
```

示例把服务中断概率目标设为 0.09。共用电源基准为 0.154，改善共用电源后为 0.0788，独立馈电模型为 0.1036。两个备选方案分别降低 0.0752 和 0.0504，只有前者达到示例目标。该排序取决于示例的输入概率，实际评审还要核对故障定义、分析周期、概率来源和实施成本。 [本轮可下载报告](https://github.com/btlqql/moon-faultgraph/releases/tag/v0.4.1)

非单调切换模型算得顶事件概率 0.086，同时列出三个最小条件，含与模式无关的两路均失效。若强制替代模式不发生，概率会上升至 0.100。报告保留这种方向差异，便于评审者核对哪些干预值得继续调查。

## 验证与边界

独立脚本用 64 组真值表核对顶事件概率、三种重要度和完整有符号项，其中 40 组额外验证正割集、区间和修复。MEF 测试覆盖共享事件、模型往返、投票门、非法引用、循环和外部 DTD 拒绝。SCRAM 互操作对照由公共 CI 从固定版本构建并运行，记录见验证入口。 [验证记录](VALIDATION.md)

项目复用 MoonBit XML 解析库，风险计算、MEF 语义处理和方案比较均由 MoonBit 完成。每个模型限于平面静态故障树、公开事件、独立基础变量及固定概率。公开仓库保留本期增量、可运行示例、测试和来源说明。 [官方十一月验收标准](https://github.com/moonbitlang/Hackathon2026/blob/2ca8a6440a5d6d1881104538852bf5f05c90c68e/src/App.tsx#L204-L214) · [生态对照](ECOSYSTEM.md) · [来源与许可](../THIRD_PARTY.md)
