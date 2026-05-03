---
name: px4-param-define
version: "1.0.0"
description: 参数定义代码生成器 - 输入参数列表，一键生成完整参数定义、DEFINE_PARAMETERS 代码、QGC 配置。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---

参数定义代码生成器：$ARGUMENTS

根据用户输入的参数列表，自动生成完整的参数定义框架（module.yaml + DEFINE_PARAMETERS + QGC 配置）。

---

## 第零步：需求确认

询问用户：

1. **模块名称**（如 `custom_app`）
2. **参数列表**（格式：`参数名 类型 默认值 最小值 最大值 [单位] [描述]`）
   - 类型：`INT32`, `FLOAT`, `INT64`
   - 示例：
     ```
     CUSTOM_APP_GAIN FLOAT 1.0 0.0 10.0 — 控制增益
     CUSTOM_APP_TIMEOUT INT32 1000 100 5000 ms 超时时间
     ```

---

## 第一步：生成 module.yaml

目标文件：`src/modules/<module_name>/module.yaml`

```yaml
module_name: Custom App
parameters:
  CUSTOM_APP_GAIN:
    description: 控制增益
    type: float
    default: 1.0
    min: 0.0
    max: 10.0
    unit: —
    category: Custom App
    volatile: false
    reboot_required: false
```

---

## 第二步：生成 DEFINE_PARAMETERS 代码

目标文件：`src/modules/<module_name>/<ModuleName>Params.hpp`

```cpp
#pragma once
#include <px4_platform_common/module_params.h>

DEFINE_PARAMETERS(
    (ParamFloat<px4::params::CUSTOM_APP_GAIN>)      _param_gain,
    (ParamInt<px4::params::CUSTOM_APP_TIMEOUT>)     _param_timeout_ms
)
```

---

## 第三步：生成模块集成代码

目标文件：`src/modules/<module_name>/<ModuleName>.hpp`

```cpp
#pragma once
#include <px4_platform_common/module_params.h>

class CustomApp : public ModuleParams
{
public:
    CustomApp();
    void update_params();
private:
    DEFINE_PARAMETERS(
        (ParamFloat<px4::params::CUSTOM_APP_GAIN>)      _param_gain,
        (ParamInt<px4::params::CUSTOM_APP_TIMEOUT>)     _param_timeout_ms
    )
    float   _gain{1.0f};
    int32_t _timeout_ms{1000};
};
```

---

## 第四步：生成参数校验代码

目标文件：`src/modules/<module_name>/<ModuleName>.cpp`

```cpp
void CustomApp::update_params()
{
    updateParams();
    _gain = _param_gain.get();
    _timeout_ms = _param_timeout_ms.get();

    // 范围校验
    if (_gain < 0.0f || _gain > 10.0f) {
        _gain = (_gain < 0.0f) ? 0.0f : 10.0f;
    }
    if (_timeout_ms < 100 || _timeout_ms > 5000) {
        _timeout_ms = (_timeout_ms < 100) ? 100 : 5000;
    }
}
```

---

## 第五步：生成 QGC 参数配置

自动从 `module.yaml` 生成，编译后位于：
```
build/px4_sitl_default/parameters.xml
```

---

## 第六步：输出文件清单

生成 4 个文件：
1. `src/modules/<module_name>/module.yaml`
2. `src/modules/<module_name>/<ModuleName>Params.hpp`
3. `src/modules/<module_name>/<ModuleName>.hpp`（参数集成）
4. `src/modules/<module_name>/<ModuleName>.cpp`（参数校验）

---

## 第七步：编译验证

```bash
cd ~/px4agent
make px4_sitl_default
```

---

## 编码规范

- 参数名全大写，下划线分隔
- 禁止硬编码参数值
- 参数读取后必须范围校验
- 禁止高频路径频繁读参数
