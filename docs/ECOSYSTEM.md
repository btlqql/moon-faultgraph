# 与相邻项目的职责对照

| 项目 | 主要职责 | MoonFaultGraph 本轮交付 |
|---|---|---|
| SCRAM | 成熟的概率风险分析工具，提供故障树、重要度和 MEF 支持 | 将受限静态分析封装为可跨 MoonBit 后端调用的库，并将 SCRAM 用作输入交换与数值对照 |
| moon-reliability | MoonBit 可靠性工程库，含寿命分布、系统/网络可靠性和故障树辅助能力 | 共享变量 Boolean DAG 的 BDD 求值、有符号素蕴含项、MEF 子集与模型修改前后的可复现情景 |

BDD、重要度和素蕴含项采用已知方法。本次交付是 MoonBit 原生分析接口、可互操作静态模型及其验证流程。 [SCRAM](https://github.com/rakhimov/scram) · [moon-reliability](https://github.com/wcx789ll/moon-reliability)
