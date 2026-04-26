---
name: px4-module
version: "1.0.0"
description: 在 PX4 项目中创建一个新业务模块（含 CMake、uORB、参数定义）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
在 PX4 项目中创建一个新模块：$ARGUMENTS

## 项目路径
- PX4 项目：`~/px4agent`
- 模块目录：`src/modules/`

## 步骤

### 第一步：确认需求
询问用户：
- 模块名称和功能描述
- 触发方式（uORB 事件驱动 or 定时调度）
- 需要订阅/发布的 uORB topics
- 是否需要参数

### 第二步：搜索现有模块
在 `src/modules/` 下查找类似功能的模块作为参考。

### 第三步：创建模块文件
在 `src/modules/<module_name>/` 下创建：
- `<ModuleName>.hpp` / `<ModuleName>.cpp`：继承 `ModuleBase` + `ModuleParams`
- `CMakeLists.txt`：用 `px4_add_module`
- `Kconfig`：模块配置
- `module.yaml`：参数定义（如有参数）

### 第四步：实现核心逻辑
- uORB 事件驱动：用 `SubscriptionCallbackWorkItem`
- 定时调度：用 `ScheduledWorkItem` + `ScheduleOnInterval()`
- 参数：`DEFINE_PARAMETERS` + `ModuleParams`，命名格式 `<PREFIX>_*`
- 禁止在 `Run()` 中阻塞

### 第五步：单元测试
- 在 `src/modules/<module_name>/test/test_<module_name>.cpp` 编写 Google Test
- 用 `px4_add_unit_gtest` 注册

## 编码规范
- 禁止 `printf`/`fprintf`，用 `PX4_DEBUG`/`PX4_INFO`/`PX4_WARN`/`PX4_ERR`
- 时间：`hrt_absolute_time()`
- 禁止动态内存分配
- 禁止硬编码参数值
