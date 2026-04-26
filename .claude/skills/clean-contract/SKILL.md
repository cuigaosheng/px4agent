---
name: clean-contract
version: "1.0.0"
description: 列出并删除 .claude/contracts/ 下所有残留的契约文件（.gitkeep 除外）。
disable-model-invocation: false
allowed-tools: [Bash, Read]
---
清理 `.claude/contracts/` 目录下所有残留契约文件：$ARGUMENTS

## 执行步骤

1. 列出 `.claude/contracts/` 下所有 `*.contract.md` 文件
2. 对每个文件，读取并展示：
   - 任务名称（文件名）
   - `状态:` 字段
   - `生成时间:` 字段
3. 向用户展示完整列表，格式如下：

```
发现 N 个残留契约：
  1. <filename>  状态: <status>  生成时间: <time>
  2. ...
```

4. 询问用户：**全部删除** / **选择保留** / **取消**
5. 按用户指令删除对应文件
6. 输出：`已清除 N 个契约文件，contracts/ 目录已清空。`

## 注意

- `.gitkeep` 文件**不得删除**
- 若目录下无 `*.contract.md` 文件，输出：`contracts/ 目录无残留契约。`
- 此命令不影响任何 skill 执行状态，仅清理文件系统
