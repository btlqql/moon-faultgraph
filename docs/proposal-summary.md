# MoonFaultGraph 一页项目说明

**用 MoonBit 比较冗余供电方案 · 0.4.1**

面向系统设计人员的冗余供电评审。一次载入共用电源基准和备选方案，以同一个服务中断目标比较故障概率、相对基准的变化和达标情况，再查看各方案中预防事件的影响。报告记录概率口径，供评审复算。

本轮对应初审补齐三项能力。重要度按 SCRAM 的 DIF、RAW、RRW 定义计算。有符号素蕴含项支持 NOT 和模式切换，能解释两条路径同时失效所形成的与模式无关的故障条件。共享事件使用同一基础变量，支持命名门、状态常量、固定概率及投票门。

供电案例的基准概率是 0.154，改善共用电源后为 0.0788，独立馈电为 0.1036。在示例设定的 0.09 目标下，只有改善共用电源的方案达标。模式切换样例验证有符号素蕴含项与预防可能增加风险的情形。独立真值表及 SCRAM 对照覆盖核心分析和 MEF 往返。适用范围为平面静态故障树和独立基础事件。

```sh
moon update
moon run cmd/main --target js -- examples/power-design-review.json
```

[GitHub](https://github.com/btlqql/moon-faultgraph) · [MoonCakes 0.4.1](https://mooncakes.io/docs/btlqql/moon_faultgraph@0.4.1) · [评审报告附件](https://github.com/btlqql/moon-faultgraph/releases/tag/v0.4.1) · [完整申报书](proposal.md) · [验证记录](VALIDATION.md)
