# MoonFaultGraph 项目申报书

**MoonFaultGraph 0.4.0 · 静态故障树互操作与风险评审工具**

参赛账号 btlqql，主要实现语言 MoonBit，代码许可证 Apache-2.0。 [GitHub 仓库](https://github.com/btlqql/moon-faultgraph) · [MoonCakes](https://mooncakes.io/docs/btlqql/moon_faultgraph@0.4.0)

## 实际任务

系统设计人员在评审冗余供电时，需要检查两条转换路径是否共享上游电源，识别影响最大的事件，并比较改善某组件和改变架构的效果。本工具读入标准子集的故障树模型，对故障概率、重要度和故障组合给出可复查结果，再将调整后的模型导出供其他工具继续检查。

## 对应初审的本轮增量

| 审核关注点 | 本轮实现 |
|---|---|
| 常见重要度 | 输出 FV/DIF、RAW、RRW、Birnbaum 与强制发生/不发生情景概率。对零分母输出状态，便于程序可靠读取。 |
| 非单调模型 | 以带符号字面量表示素蕴含项。对 BDD 的两个余因子及其交集求项，去除被包含的项，以发现跨分支的最小故障条件。 |
| 模型交换 | 解析 Open-PSA MEF 静态 XML 子集，对命名门、共享基础事件、固定概率、状态常量和投票门建立语义模型。支持按名称修改概率和重新导出。 |

设基准概率为 Q、强制事件发生和不发生后的概率为 Q1 和 Q0。RAW 计算 Q1/Q，RRW 计算 Q/Q0，FV 采用 SCRAM 的 DIF 定义 p×Q1/Q。非单调模型中，Birnbaum 可能为负，应结合两个强制情景解释其方向。 [SCRAM 定义](https://github.com/rakhimov/scram/blob/develop/doc/theory.rst#importance-analysis)

## 运行案例

```sh
moon update
moon run cmd/main --target js -- examples/shared-power-review.json
moon run cmd/main --target js -- examples/independent-power-review.json
moon run cmd/main --target js -- examples/mode-switch-review.json
```

在双路供电的合成评审模型中，当前共用电源结构的顶事件概率为 0.154。将共用电源失效概率由 0.10 调整为 0.02 后，结果为 0.0788。使用例中独立馈电模型，结果为 0.1036。报告保留各方案假设、共享事件和分析结果，便于核对改动影响。输入概率是演示参数。

非单调切换模型算得顶事件概率 0.086，同时列出正常模式且主路失效、替代模式且替代路失效，以及两路均失效这三个最小条件。最后一项不依赖模式状态。

## 验证与边界

独立脚本用 64 组真值表核对顶事件概率、三种重要度和完整有符号项，其中 40 组额外验证正割集、区间和修复。MEF 测试覆盖共享事件、模型往返、投票门、非法引用、循环和外部 DTD 拒绝。SCRAM 互操作对照由公共 CI 从固定版本构建并运行，记录见验证入口。 [验证记录](VALIDATION.md)

项目复用 MoonBit XML 解析库，主要风险计算和 MEF 语义处理由本项目 MoonBit 源码完成。范围为单个平面静态故障树、公开事件、独立基础变量及固定概率。发布材料提供使用说明、验证记录和代码历史。 [生态对照](ECOSYSTEM.md) · [来源与许可](../THIRD_PARTY.md)
