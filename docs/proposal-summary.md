# MoonFaultGraph项目申报书

**共享事件Boolean故障图与冗余架构分析**

账号：btlqql；版本：0.3.0；主要语言：MoonBit；许可：Apache-2.0。

## 解决的问题与使用场景

当冗余分支共用同一电源或服务依赖时，保持事件身份，计算故障概率、最小割集、条件结果与单事件修复效果。

## 已实现功能与技术路线

ROBDD唯一表、归约与Apply缓存，AND/OR/NOT/投票门，概率、有符号重要度、正事件最小割集、条件证据、单调概率区间及单事件修复情景。

## 完整案例

(A AND B) OR (A AND C)在p=(0.1,0.2,0.3)时概率0.044；区间上端(0.2,0.3,0.4)给0.116。使共享A不发生后剩余顶事件概率为0。 运行`moon run cmd/main --target js -- examples/uncertainty-and-repair.json`可复现。

## 独立贡献与验证

已有fault_tree_and/or、最小割集概率和网络可靠性等相邻能力。本项目的区分是共享变量通用Boolean DAG的ROBDD编译及统一求值/诊断流程，不把故障树领域称为空白。 当前8项MoonBit测试；64组Boolean真值表模型，其中40组同时枚举最小割集、区间端点及单事件修复结果。 相邻项目对照见docs/ECOSYSTEM.md，来源与许可见THIRD_PARTY.md。

## 当前边界

不同基础变量必须统计独立；重复变量是同一事件。割集/区间/修复仅接受语法无NOT的单调模型。区间是参数范围，不是置信区间。单事件修复结果不可相加推断组合修复。未实现动态故障树、任意相关联合分布或故障率估计。

GitHub：https://github.com/btlqql/moon-faultgraph。模块：btlqql/moon_faultgraph@0.3.0。AI辅助开发；公开提交、CI和独立安装以实际核验记录为准，开源发布不代表比赛报名或验收通过。
