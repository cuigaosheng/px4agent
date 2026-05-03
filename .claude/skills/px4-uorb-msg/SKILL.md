---
name: px4-uorb-msg
version: "1.0.0"
description: uORB 消息代码生成器 - 输入消息名称和字段，一键生成完整消息定义、发布器、订阅器、单元测试。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---

uORB 消息代码生成器：$ARGUMENTS

根据用户输入的消息名称和字段列表，自动生成完整的 uORB 消息框架（消息定义 + 发布器 + 订阅器 + 单元测试）。

---

## 第零步：需求确认

询问用户：

1. **消息名称**（如 `custom_sensor_data`）
2. **字段列表**（格式：`类型 字段名 [# 注释]`，每行一个）
   - 支持类型：`uint8_t`, `int8_t`, `uint16_t`, `int16_t`, `uint32_t`, `int32_t`, `uint64_t`, `int64_t`, `float`, `double`, `bool`, `char[N]`
   - 示例：
     ```
     uint32_t sensor_id
     float temperature_c
     uint16_t pressure_pa
     bool is_valid
     ```
3. **消息用途**（一句话描述）

---

## 第一步：生成消息定义文件

目标文件：`src/modules/uORB/topics/<message_name>.msg`

```
# <消息用途>
uint64 timestamp
<type> <field_name>
...
```

---

## 第二步：生成发布器代码

目标文件：`src/modules/custom_app/<MessageName>Publisher.hpp`

```cpp
#pragma once
#include <px4_platform_common/px4_config.h>
#include <uORB/Publication.hpp>
#include <uORB/topics/<message_name>.h>
#include <drivers/drv_hrt.h>

class <MessageName>Publisher
{
public:
    <MessageName>Publisher() : _pub{ORB_ID(<message_name>)} {}
    void publish(const <message_name>_s &msg) { _pub.publish(msg); }
private:
    uORB::Publication<<message_name>_s> _pub;
};
```

---

## 第三步：生成订阅器代码

目标文件：`src/modules/custom_app/<MessageName>Subscriber.hpp`

```cpp
#pragma once
#include <px4_platform_common/px4_config.h>
#include <uORB/Subscription.hpp>
#include <uORB/topics/<message_name>.h>

class <MessageName>Subscriber
{
public:
    <MessageName>Subscriber() : _sub{ORB_ID(<message_name>)} {}
    bool updated() const { return _sub.updated(); }
    bool copy(<message_name>_s &msg) { return _sub.copy(&msg); }
private:
    uORB::Subscription<<message_name>_s> _sub;
};
```

---

## 第四步：生成单元测试

目标文件：`src/modules/uORB/topics/test/test_<message_name>.cpp`

```cpp
#include <gtest/gtest.h>
#include <uORB/Publication.hpp>
#include <uORB/Subscription.hpp>
#include <uORB/topics/<message_name>.h>

TEST(MessageTest, PublishAndSubscribe)
{
    uORB::Publication<<message_name>_s> pub{ORB_ID(<message_name>)};
    uORB::Subscription<<message_name>_s> sub{ORB_ID(<message_name>)};

    <message_name>_s msg{};
    msg.timestamp = hrt_absolute_time();
    pub.publish(msg);
    usleep(100);

    EXPECT_TRUE(sub.updated());
}
```

---

## 第五步：输出文件清单

生成 4 个文件：
1. `src/modules/uORB/topics/<message_name>.msg`
2. `src/modules/custom_app/<MessageName>Publisher.hpp`
3. `src/modules/custom_app/<MessageName>Subscriber.hpp`
4. `src/modules/uORB/topics/test/test_<message_name>.cpp`

---

## 第六步：编译验证

```bash
cd ~/px4agent
make px4_sitl_default
```

---

## 编码规范

- 第一字段必须是 `uint64 timestamp`
- 禁止动态数组、指针、浮点运算
- 时间戳用 `hrt_absolute_time()`
