# MoonFaultGraph

共享事件Boolean故障图与冗余架构分析，主要业务机制由MoonBit实现，Apache-2.0。

当冗余分支共用同一电源或服务依赖时，保持事件身份，计算故障概率、最小割集、条件结果与单事件修复效果。

## 可运行任务

```sh
moon run cmd/main --target js -- examples/uncertainty-and-repair.json
moon run cmd/main --target js -- examples/shared-power-diagnosis.json
```

(A AND B) OR (A AND C)在p=(0.1,0.2,0.3)时概率0.044；区间上端(0.2,0.3,0.4)给0.116。使共享A不发生后剩余顶事件概率为0。

range.lower/upper指定独立基础事件概率上下端点；mitigations=true输出逐事件修复。diagnose=true可输出完整正事件割集与observations条件结果。

CLI读取JSON文件，ok表示计算执行成功；领域可行性、超时或削波需读取各自字段。Node只读写文件、设置退出码和封装PCM；核心算法不转发给Python/C或外部服务。

## 可复用接口与安装

```sh
moon add btlqql/moon_faultgraph@0.3.0
```

在moon.pkg导入`"btlqql/moon_faultgraph" @core`；完整签名见[pkg.generated.mbti](pkg.generated.mbti)。

ROBDD唯一表、归约与Apply缓存，AND/OR/NOT/投票门，概率、有符号重要度、正事件最小割集、条件证据、单调概率区间及单事件修复情景。

## 验证

```sh
moon check --target all --deny-warn
moon test --target js --deny-warn
moon test --target wasm --deny-warn
moon test --target wasm-gc --deny-warn
python scripts/verify.py
```

当前8项MoonBit测试。独立开发对照：64组Boolean真值表模型，其中40组同时枚举最小割集、区间端点及单事件修复结果。

脚本只需要Python标准库、Node与MoonBit；可用MOON_BIN指定moon路径。产物保存在本仓库_build/oracle，脚本不下载外部库，不访问相邻工作区。CI覆盖JS/Wasm/Wasm-GC/native，实际运行状态见[Actions](https://github.com/btlqql/moon-faultgraph/actions)。本地验证和公共CI结论分别记录，不用静态检查冒称native运行。

## 实现边界与来源

不同基础变量必须统计独立；重复变量是同一事件。割集/区间/修复仅接受语法无NOT的单调模型。区间是参数范围，不是置信区间。单事件修复结果不可相加推断组合修复。未实现动态故障树、任意相关联合分布或故障率估计。

对照详见[ECOSYSTEM](docs/ECOSYSTEM.md)，归属见[THIRD_PARTY](THIRD_PARTY.md)。实例是软件模型或合成输入，不是生产部署证明。

## 申报与开发记录

[完整版Markdown申报书](docs/proposal.md) | [一页Markdown摘要](docs/proposal-summary.md) | [实际提交历史](https://github.com/btlqql/moon-faultgraph/commits/main/)

版本0.3.0。GitHub提交保留真实时间与每次文件变化；不以数量替代独立价值和实际质量。十一月规则尚未从公开页面完整确认，开源发布不等于比赛报名或验收通过。
