---
name: review
version: "1.0.0"
description: 对当前修改的代码进行安全审查，重点检查 PX4 编码规范违反项。
disable-model-invocation: true
allowed-tools: [Read, Glob, Grep]
---
对当前修改的代码进行安全审查，重点检查以下项目：$ARGUMENTS

## 安全审查清单

### 内存安全
- [ ] 数组访问：是否用 `ARRAY_SIZE()` 做边界检查
- [ ] 整型溢出：位宽和单位换算中间值是否安全
- [ ] 禁止动态内存分配（new/delete/malloc/free）
- [ ] 禁止在驱动层使用浮点运算

### 空指针 & 资源
- [ ] uORB copy 返回值是否检查
- [ ] DroneCAN 回调是否判空
- [ ] perf_free() 是否在析构中调用
- [ ] 文件描述符是否关闭

### 状态机
- [ ] enum switch 是否有 default 分支
- [ ] 状态转换是否有超时保护

### 通信数据
- [ ] 外部输入（MAVLink/DroneCAN）是否范围校验后再写 uORB
- [ ] 传感器超时是否上报健康异常

### PX4 规范
- [ ] 禁止 `printf`/`fprintf`，用 `PX4_DEBUG`/`PX4_INFO`/`PX4_WARN`/`PX4_ERR`
- [ ] 时间使用 `hrt_absolute_time()`，禁止系统时钟
- [ ] 参数通过 `DEFINE_PARAMETERS` + `ModuleParams`，禁止裸调 `param_get()`
- [ ] 禁止硬编码参数值
- [ ] `Run()` 中是否有阻塞操作（禁止）
- [ ] 是否误用 Cyphal(v1)（应只用 UAVCAN v0）

## 输出格式
对每个问题：
1. 标注文件路径和行号
2. 描述问题
3. 给出修复代码
