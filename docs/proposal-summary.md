# MoonFaultGraph 一页项目说明

**以 MoonBit 分析与交换静态故障树 · 0.4.0**

面向系统设计人员的冗余供电与共享依赖评审。导入 Open-PSA MEF 静态 XML，输出顶事件概率、FV/DIF、RAW、RRW 和素蕴含项。调整事件概率后可导出同一结构的 XML，再在其他工具核对。

本轮对应初审补齐三项能力。重要度按 SCRAM 的 DIF、RAW、RRW 定义计算。有符号素蕴含项支持 NOT 和模式切换，能解释两条路径同时失效所形成的与模式无关的故障条件。共享事件使用同一基础变量，支持命名门、状态常量、固定概率及投票门。

供电案例给出 0.154 的基准概率，改善共用电源后为 0.0788，独立馈电示例为 0.1036。三项均基于可复查的模型参数。模式切换案例给出 0.086 与三个素蕴含项。独立脚本对 64 组模型做真值表对照，公开 CI 另运行 SCRAM 对照。支持范围为平面静态故障树和独立基础事件。

```sh
moon update
moon run cmd/main --target js -- examples/shared-power-review.json
```

[GitHub](https://github.com/btlqql/moon-faultgraph) · [MoonCakes 0.4.0](https://mooncakes.io/docs/btlqql/moon_faultgraph@0.4.0) · [完整申报书](proposal.md) · [验证记录](VALIDATION.md)
