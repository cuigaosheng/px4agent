---
name: simplify
version: "1.0.0"
description: 审查已改动代码的质量和冗余，给出精简建议并修复。
disable-model-invocation: true
allowed-tools: [Read, Glob, Grep, Edit]
---
审查当前会话中已改动的代码，找出可精简的部分：$ARGUMENTS

## 审查维度

### 重复与冗余
- [ ] 是否有可用已有工具/函数替代的手写逻辑
- [ ] 是否有复制粘贴的重复代码块（3 行以上相似逻辑）
- [ ] 是否有仅被调用一次、可内联的私有函数

### 过度设计
- [ ] 是否为只用一次的操作引入了 helper/util 类
- [ ] 是否有为"未来可能有用"而添加的参数或接口
- [ ] 是否有可用简单条件代替的状态机

### PX4 特定冗余
- [ ] `perf_counter` 是否有未被 `print_status()` 输出的孤立计数器
- [ ] uORB advertise/subscribe 是否有重复的实例
- [ ] 参数是否有未被 `updateParams()` 刷新的死参数

## 输出格式
对每个问题：
1. 标注文件路径和行号
2. 描述冗余原因
3. 给出精简后的代码
