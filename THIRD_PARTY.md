# 来源与归属

本项目为 AI 辅助的 MoonBit 实现，许可证为 Apache-2.0。分析核心使用 MoonBit core，MEF 子包通过 Milky2018/xml 0.5.0 读取和写出 XML，语义解析和故障分析由本项目实现。JS 宿主负责文件读写和退出状态。 [XML 库及许可](https://github.com/moonbit-community/xml-mbt)

成熟算法与领域参考见README和docs/ECOSYSTEM.md，未将第三方算法源码移植后冒称原创。其他参赛项目仅作为职责对照，相关链接和职责对照见docs/ECOSYSTEM.md，不属于本项目生产代码。

SCRAM 0.16.2 是独立 CI 对照工具，由工作流从固定上游源码构建。SCRAM 程序和测试输入保留上游许可，通过 CI 使用。Open-PSA MEF 规范用于格式定义。 [SCRAM 版本](https://github.com/rakhimov/scram/tree/9c9a75ca0c5c2fbb5b4a7d32e29fd25bf90f7bab) · [MEF 规范](https://open-psa.github.io/mef/)
