# MoonFaultGraph 项目申报书

**0.5.0 · 面向供电与联锁评审的多树 MEF 互操作工具**

参赛账号 btlqql，核心实现语言 MoonBit，开源许可证 Apache-2.0。

## 实际用途

系统设计人员收到一份包含多个设备和联锁组件的故障树文档时，需要分清哪些故障是跨系统共享的，哪些只是同名。MoonFaultGraph 读入这类 Open-PSA MEF 模型，按指定顶事件计算概率、重要度与有符号素蕴含项，并导出调整参数后的原结构 XML，供团队复核。

## 对应复审意见的修改

| 审核关注点 | 0.5.0 交付 |
| --- | --- |
| 单棵平面树 | 同一 XML 导入多棵故障树和嵌套组件，按公开名或完整路径选择顶事件。 |
| 缺少异或等静态门 | 导入、计算和导出 XOR、NAND、NOR，导出保留原门标签。 |
| 缺少限定名与往返证明 | 支持公开短名、相对路径和完整限定名，并保留私有同名事件的独立身份。逐节点检查导出结构，对同一导出文件的两个顶事件重新分析。 |

## 可复算的往返案例

案例仅把 `PlantA.Power` 从 0.10 调至 0.25。XML 保留同名的 `PlantA.Pump.Power` 和 `PlantB.Power`。第二棵树直接引用变更事件，因此两棵树的结果都变化。

| 顶事件 | 原模型概率 | 导出后重导入 | 有符号素蕴含项 |
| --- | ---: | ---: | ---: |
| `PlantA.Top` | 0.804 | 0.690 | 3 |
| `PlantB.Top` | 0.378 | 0.315 | 1 |

示例使用固定假设概率。工具支持静态故障树和独立基础变量。对照脚本用 SCRAM 0.16.2 逐顶事件核对原模型与导出模型的概率和带符号项。纯 NOR 的强制状态重要度另用独立真值表验证。 [模型输入](../examples/scoped-power.xml) · [验证说明](VALIDATION.md)

```sh
moon update
moon run cmd/main --target js -- examples/scoped-power-plant-a.json
moon run cmd/main --target js -- examples/scoped-power-plant-b.json
```

[GitHub 仓库](https://github.com/btlqql/moon-faultgraph) · [SCRAM 对照附件入口](https://github.com/btlqql/moon-faultgraph/releases/download/v0.5.0/scram-comparison.json) · [MoonCakes 版本入口](https://mooncakes.io/docs/btlqql/moon_faultgraph@0.5.0)
