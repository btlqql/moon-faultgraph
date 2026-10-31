# MoonFaultGraph

对共享基础事件的Boolean故障图进行概率分析。首批实现，模块名november/moon_faultgraph为本地开发命名空间，未发布。

最容易出错的情况是多个分支引用同一个电源/设备：同一事件不能按独立副本重复计算。本库将同一个变量编号的每次出现编译成同一Boolean变量，通过ROBDD计算顶事件概率。不同变量仍必须统计独立；这不是任意相关概率模型。

已实现有序DAG校验、AND/OR/NOT/k-of-n门、唯一表、归约、Apply缓存、概率和有符号Birnbaum重要度。compile接收按拓扑顺序排列的Gate，引用只能指向前面的Gate；最后一个Gate是顶事件。Event(n)指向probabilities[n]。投票按输入位置计数，重复输入共享变量身份，因此vote(2,[A,A])等价于A。完整API见pkg.generated.mbti。

```powershell
moon run cmd/main --target js -- examples/shared-power.json
moon test --target wasm-gc --deny-warn
```

示例：(A AND B) OR (A AND C)，基础概率[0.1,0.2,0.3]，结果0.044，A的重要度0.44；错误独立分支公式会给0.0494。它是自制冗余系统模型，不是部署数据。CLI的ok表示计算成功，不代表模型安全或风险可接受。错误退出1。

概率使用Double，Boolean逻辑精确表示不等于任意精度概率数值；无稀有事件近似。含NOT时重要度允许为负。最多128个变量、4096个门，默认100,000个分配BDD节点，硬上限1,000,000；Apply缓存最多为节点预算的8倍。变量顺序固定为编号顺序，某些结构会指数膨胀并明确报ResourceLimit，不能用规模限制冒充任意模型可扩展。node_count包括终端与编译中间节点，不是可达最终图节点数。

尚未实现最小割集、动态故障树、共同原因参数估计、文件内命名引用或SCRAM格式互操作。

wcx789ll/moon-reliability已经有基础故障树及网络可靠性API；本项目不将故障树称为生态空白。当前独立核验的增量是共享变量的通用Boolean DAG编译与概率求值，详见上级制作总方案和evidence中的对照接口。

开发对照使用60组随机模型的独立真值表穷举，包括重复变量、否定及投票；运行上级verify.py，证据在../../evidence/validation.json。参考[SCRAM的BDD分析说明](https://github.com/rakhimov/scram/blob/develop/doc/probability_analysis.rst)，未复制或链接其GPL源码。Apache-2.0，AI辅助实现。
