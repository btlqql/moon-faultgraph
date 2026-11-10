# 开发历史与计数边界

以下为首次公开代码的10条实际提交，保留真实日期。每条均包含文件变化；不倒填、不重写、不建空提交。数量涵盖核心功能、修复、验证、集成、CI和文档，不代表主办方已认可全部为有效参赛提交。

```text
80f172c | 2026-10-31T19:27:20+08:00 | Implement initial domain core, executable example and boundary tests
a21616a | 2026-10-31T19:36:13+08:00 | Add planning, diagnosis and moving audio workflows; fix boundary semantics
d0ae66b | 2026-10-31T19:42:25+08:00 | Document implemented 0.2.0 behavior and validated boundaries
c22e81a | 2026-10-31T19:48:25+08:00 | Configure btlqql module namespace, repository metadata and package exclusions
a7ee212 | 2026-10-31T19:49:14+08:00 | Add coherent probability intervals and individual mitigation analysis
a7386af | 2026-10-31T19:50:12+08:00 | Expose probability ranges and independent repair scenarios in file requests
364cb99 | 2026-10-31T19:51:36+08:00 | Add executable regression fixtures and adversarial state-boundary tests
c57b747 | 2026-10-31T19:52:36+08:00 | Add self-contained independent verification runnable from a clean repository
ca493c6 | 2026-10-31T19:53:19+08:00 | Run portable tests on four backends and independent file-workflow oracles in CI
0933686 | 2026-10-31T19:55:28+08:00 | Document complete runnable workflows, ecosystem differences and Markdown applications for release
```

用户本轮明确确认：比赛要求为每个参赛仓库至少10次提交，没有另列起始或截止时间。本项目按仓库真实历史计数，不再将旧通知的9月1日或假设的11月1日另作本轮门槛。

0.4.1 在原仓库的静态 MEF 分析基础上增加批量方案评审。模型替换与概率覆盖复用原解析和分析接口，每个备选方案单独保存有效参数。事件预防效果保留符号，基准概率为零时，相对变化保留空值。输入校验补上 MEF 小数写法、投票门整数阈值和结构化文件错误。 [0.4.0 基线](https://github.com/btlqql/moon-faultgraph/tree/v0.4.0) · [开发提交](https://github.com/btlqql/moon-faultgraph/commits/main/) · [验证记录](VALIDATION.md)
