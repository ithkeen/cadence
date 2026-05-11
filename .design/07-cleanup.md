# /cadence:cleanup 设计（已定稿）

## 命名说明
辅助命令，不在 spec → design → run → archive 主链路中。承担「中途放弃当前 cycle」的兜底清理。命令名定为 **cleanup**（候选 abandon / discard / reset 已否）。

## 定位
让 `.cadence/` 回到可重新 spec 的状态。**唯一职责：删 CURRENT 指向的 cycle 目录 + 清空 CURRENT**。

明确不做：
- 不回滚代码（run 阶段已 commit 的改动不管）
- 不动 PROJECT.md
- 不动其他 cycle 目录
- 不读 cycle 内任何文件
- 不询问用户、不二次确认
- 不接受参数（`$ARGUMENTS` 被忽略）

## 触发场景
- spec 调研环节已建目录但用户取消 → 留下孤儿目录 + CURRENT 占位
- spec 落档后用户后悔，不想继续 design
- design 后推翻方案
- plan 后弃用
- run 跑到一半决定放弃

任意一种情形下，跑 `/cadence:cleanup` 即可让 spec 启动前置检查重新放行。

## 调用形式
```
/cadence:cleanup
```
不带参数。

## 前置条件
无。任何状态都可调用，包括 CURRENT 为空。

## 流程
1. Read `.cadence/CURRENT`
   - 文件不存在 / trim 后为空 → 输出"无需清理"，退出
   - 存在且非空 → trim 后内容作为 `<cycle-dir>`
2. 前缀校验：`<cycle-dir>` 必须以 `cycle-` 开头，否则报错退出（防止 CURRENT 被污染导致 `rm` 路径越权）
3. Bash `rm -rf .cadence/<cycle-dir>`（目录不存在不会报错，不前置判断）
4. Write `.cadence/CURRENT` 为空字符串
5. 简报：`✅ Cycle <cycle-dir> 已清理。可重新运行 /cadence:spec 开始新需求。`

## 关键设计原则

### 极简，不做「贴心」功能
- 不展示要删什么
- 不二次确认
- 不分阶段判断
- 不接受参数指定 slug

理由：用户已经明确想丢弃当前 cycle 才会主动调用，增加交互反而打扰。

### 不管 git
run 阶段 task-executor 已 commit 的代码改动不属于 cleanup 职责。需要回滚代码用户自行 `git revert` / `git reset`。

理由：cleanup 的语义是「我不要 cadence 的流程产物了」，不是「撤销开发工作」。职责分离。

### 不动 PROJECT.md
被清理的 cycle 没归档过，PROJECT.md 本就不含其内容。即使 run 跑完但用户不想 archive，PROJECT.md 仍是上一次 archive 后的状态，无需处理。

### 前缀校验是唯一防线
`rm -rf .cadence/<cycle-dir>` 直接拼接 CURRENT 内容存在路径注入风险（如 `..` 或绝对路径）。强制 `<cycle-dir>` 以 `cycle-` 开头是封死这个口子的最低成本方案。

## 工具白名单
`Read, Write, Bash`

不需要 Edit / Agent / AskUserQuestion / Grep / Glob。

## 与其他命令的协作
- spec 启动前置检查：CURRENT 非空时拦截 → 提示用户跑 archive 或 cleanup（spec 命令的提示语建议同时提及两者）
- 不与 design / plan / run / archive 协作

## 关键约束（用户明确表达过的偏好）
- 命令名用 cleanup
- 不接受参数
- CURRENT 为空时什么都不做
- 不拦截、不提示已跑过 run 的 cycle
- 不二次确认
- 不管 git
