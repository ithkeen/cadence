---
description: 读取 may 设计文档，先调 plan-agent 拆 phase，再按依赖顺序逐个交 code-executor 实现
allowed-tools: Read, Agent
argument-hint: "<may-主题.md 路径>"
---

# 这个命令做什么

把一份 `may-<主题>.md` 跑成代码：① 调 `plan-agent` 把它拆成 `phaseN.md`；② 按依赖顺序把每个 phase 交给 `code-executor` 落地。你只做编排——不自己拆 phase、不自己写代码。

# 流程

## 0. 定位

`$ARGUMENTS` 是 may 文档路径。缺失则报错退出：

```
❌ 缺少 may 文档路径。用法：/cadence:run <may-主题.md 路径>
```

去空白得 `<may-path>`，`<output_dir>` 取其所在目录。读不到 → `❌ 路径不可读：<may-path>`。

## 1. 拆 phase

```
Agent(subagent_type="cadence:plan-agent", description="拆 phase",
      prompt="[may_path] <may-path>\n[output_dir] <output_dir>")
```

plan-agent bail / 失败 → 原样转达用户并停，不进入实现。成功则拿到 phase 清单（含各自依赖）。

## 2. 逐个实现

按依赖顺序依次实现，**前置 phase 完成才动后续**（共享同一工作树，不并行）：

```
Agent(subagent_type="code-executor", description="实现 Phase N <主题>",
      prompt="Read 并实现 <output_dir>/phaseN.md：严格按其中范围 / 技术栈 / 约束 / 验收落地，用 tdd skill 驱动，完成后跑 phase 内验证命令确认通过。任务外的功能 / 优化一律不做。")
```

- executor 回 `completed` → 继续下一个。
- executor 回 `failed: <原因>` → 停止，不再派依赖它的后续 phase，把失败 phase 与原因报给用户。

## 3. 收尾

```
✅ <主题>：<done>/<total> 个 phase 完成
- Phase 1 <主题>：completed
- Phase 2 <主题>：failed: <原因>（依赖它的 Phase 3 未执行）
```
