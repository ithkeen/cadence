# cadence:run

# 这个流程做什么

把一份 `may-<主题>.md` 跑成代码：① 调 `plan-agent` 把它拆成 `phaseN.md`；② 按依赖顺序把每个 phase 交给 `code-executor` 落地。你只做编排——不自己拆 phase、不自己写代码。

# 流程

## 0. 询问 may 文档路径 + 定位

进入 `cadence:run` 后，先向用户确认要执行的 may 技术设计文档路径：

```
这次要执行的 may 技术设计文档路径是哪一个？
```

只问路径，等用户回复后再继续；不要从触发文本里取路径。拿到用户回复的路径后记为 `<may-path>`；路径不可读 → 告诉用户 `❌ 路径不可读：<may-path>`，让用户重新给路径，不进入拆 phase。

`<output_dir>` 取 `<may-path>` 所在目录。

## 1. 拆 phase

直接调用 `plan-agent`，传入 `may_path = <may-path>`、`output_dir = <output_dir>`，要求它按 may 文档拆出 phase 文件。

`plan-agent` bail / 失败 → 原样转达用户并停，不进入实现。成功则拿到 phase 清单（含各自依赖）。

## 2. 逐个实现

按依赖顺序依次实现，**前置 phase 完成才动后续**（共享同一工作树，不并行）：

逐个直接调用 `code-executor`，传入要实现的 phase 文件路径：

```
实现 <output_dir>/phaseN.md：严格按其中范围 / 技术栈 / 约束 / 验收落地，用 tdd skill 驱动，完成后跑 phase 内验证命令确认通过。任务外的功能 / 优化一律不做。
```

- `code-executor` 回 `completed` → 继续下一个。
- `code-executor` 回 `failed: <原因>` → 停止，不再派依赖它的后续 phase，把失败 phase 与原因报给用户。

## 3. 收尾

```
✅ <主题>：<done>/<total> 个 phase 完成
- Phase 1 <主题>：completed
- Phase 2 <主题>：failed: <原因>（依赖它的 Phase 3 未执行）
```
