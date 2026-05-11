# Cadence Plugin 总体设计

## 定位
一个为 the assistant 定制的、显式调用的开发工作流 plugin。区别于 GSD/Superpowers/G-Stack：
- 命令显式触发，不全自动
- 不按"工种角色"划分（无 CEO / 架构师 / 开发等角色）
- 一个命令对应一个不重叠的产物
- 全中文输出
- 一次调用对应"一个用户预先拆好的小任务"，不让 plugin 帮忙拆里程碑

## 核心概念：Cycle
一次完整的 spec → design → run → archive 流程称为一个 **cycle**。
- cycle 大小由用户决定（单功能 / 整站 MVP / 重构 都可以）
- 每个 cycle 独占一个目录：`.cadence/cycle-<slug>/`
- slug 由 spec 阶段结束时由模型自动总结，不让用户确认

## 4 个主命令

| 命令 | 性质 | 产物 |
|---|---|---|
| `/cadence:spec` | 纯对话，不读代码 | `REQUIREMENT.md` + `REQUIREMENT.html` |
| `/cadence:design` | 对话 + 读 PROJECT.md（不读源码） | `DESIGN.md` + `DESIGN.html` |
| `/cadence:run` | 一站式：自动拆 plan（reviewer 2 轮）+ 调度子 agent 执行 | `PLAN.md` + `RUN-STATE.md` + 代码 |
| `/cadence:archive` | 更新项目档案 | 重写 `.cadence/PROJECT.md` |

## 1 个辅助命令

| 命令 | 性质 | 产物 |
|---|---|---|
| `/cadence:cleanup` | 极简兜底，不交互 | 删 CURRENT 指向的 cycle 目录 + 清空 CURRENT |

放弃当前 cycle 时使用，不在主链路。详见 `.design/07-cleanup.md`。

## 项目档案：.cadence/PROJECT.md（导航层）
- 项目级"活档案"，记录：定位、技术栈、模块地图、代码约定、关键决策、已知坑
- **不写功能详情**（功能详情在各模块 README 中）
- **只在 archive 阶段写入/更新**，不引入独立 bootstrap 命令
- design 阶段读它拿模块地图，按需深入读对应模块 README
- 不存在 → 视为 0-1 项目，design 进入"白板模式"

## 模块文档：<module>/README.md（详情层）
- 各模块的对外接口、内部约定、功能清单
- 由 `/cadence:run` 子 agent 维护：每个 task 必须更新涉及模块的 README
- 不在 plugin 产物范围内（属于代码工件），但 plugin 强制维护它

## 调研产物：.cadence/cycle-<slug>/research/
- spec / design 阶段按需调研的产物
- 由主 agent 识别"信息缺口" + 用户确认后，调起 research-agent 产生
- 不新增命令；不进入 plan/run 阶段；不进 PROJECT.md
- archive 时跟随 cycle 留档

## 当前 cycle 定位
- `.cadence/CURRENT` 文件，单行内容为当前 cycle 目录名
- spec 写入；design/plan/run/recap 读取；recap 完成后清空
- 切换 cycle = 手动改这个文件

## 子 agent 策略（/run）
- 通用型，不预设角色（不分前端/后端 agent）
- 一个 task = 一个子 agent 实例
- 主 agent 只持有 PLAN + 子 agent 摘要回执，不污染上下文
- 按 PLAN 中的依赖图调度，无依赖兄弟节点并发
- 子 agent 失败重试 1 次；仍失败则跳过其依赖者，继续跑能跑的，最后汇总

## 用户参与密度
- spec / design：对话密集（前重）
- plan：半自动，扫一眼
- run / recap：执行不打扰（后轻）
- 命令边界 = gate，命令内部不再加确认弹窗

## 产物双写策略
- `.md` 给模型读：结构化、信息密集、消歧优先
- `.html` 给人读：图文并茂、扫读高效、理解优先
- 两者**分别生成**，不是同一文档的两种格式
- HTML 中图的形式：Mermaid 图 + 纯 HTML/CSS 卡片式示意（不生成真实图片）
