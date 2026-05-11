# /cadence:archive 设计（已定稿）

## 命名说明
原候选名 recap 被否，改为 **archive**（归档）—— 准确表达"封存 cycle + 更新项目档案"。

## 定位
本 cycle 的收尾。**唯一职责：更新项目档案 PROJECT.md**。

明确不做：
- 不生成 RECAP.md（cycle 目录里的 REQUIREMENT/DESIGN/PLAN/RUN-STATE 已是足够的历史档案）
- 不生成任何 HTML
- 不维护各模块 README.md（那是 run 阶段子 agent 的职责）
- 不引入新文件

## 调用形式
```
/cadence:archive
```
不带参数。

## 前置条件（硬性）
读 RUN-STATE.md，**所有 task 必须 ✅**。任何 ❌ 直接报错退出：
```
归档失败：以下 task 仍处于阻塞状态
  ❌ T5: ...
请先解决阻塞项后重新 /cadence:run，全部完成后再归档。
```
不允许"强制归档"。失败的 cycle 必须先变成成功的 cycle。

## 流程
1. 读 CURRENT 定位 cycle
2. 校验 RUN-STATE 全部 ✅，否则报错
3. 读 REQUIREMENT + DESIGN + RUN-STATE，提取项目级变化（不关心过程）
4. 读现有 PROJECT.md（不存在则创建模式）
5. 主 agent 内存 merge → 写入 PROJECT.md（**全信任，不展示 diff、不让用户确认**）
6. 清空 `.cadence/CURRENT`
7. 简报：`Cycle <slug> 已归档，新增/修订: X`

## PROJECT.md 设计原则
**先想清楚谁用、什么时候用、需要什么信息**：

| 使用者 | 时机 | 关注什么 |
|---|---|---|
| `/cadence:design` 主 agent | 新 cycle 设计前 | 现状、模块边界、约束 |
| `/cadence:run` 子 agent | 拿到 task 后 | 项目栈、风格、模块定位 |
| 用户 | 接手项目 / 隔久回来 | 整体地图、做到哪儿了 |

共同需要：**导航 + 约束 + 现状**。
都不需要：历史、过程、详细 API、完整功能列表。

## PROJECT.md 结构

```markdown
# 项目档案

> <一句话项目定位 —— 是什么、给谁、解决什么>

## 技术栈
- 语言、框架、关键依赖、版本（只列对架构有影响的）

## 模块地图

\```mermaid
graph TD
  api --> service
  service --> db
\```

| 模块 | 职责 | 文档 |
|---|---|---|
| api/ | REST 接口层 | [api/README.md](api/README.md) |
| service/ | 核心业务逻辑 | [service/README.md](service/README.md) |

## 代码约定
> 只写本项目特有的，不写通识。
- 错误统一通过 AppError 类抛出
- ...

## 关键决策
> 为什么选 X 不选 Y。
- JWT 用 jose 而非 jsonwebtoken — 因为支持 ESM
- ...

## 已知限制 / 坑
- ...
```

关键设计：
- **不写项目名标题**
- **导航优先**：模块地图最显眼
- **当前真相**：只写"现在是什么"，不写历史
- **本项目特有**：约定/决策只写本项目独有的
- **功能详情下沉**：不写"已实现功能"章节，模块表链接各 README，按需读

## 与其他命令的协作
- design 阶段：读 PROJECT.md 拿模块地图 → 按相关性按需读对应模块 README
- run 阶段子 agent：维护各模块 README（job description 里写明）
- archive 阶段：只重建/合并 PROJECT.md，不动 README

## 关键约束（用户明确表达过的偏好）
- 名字用 archive 不用 recap
- 不引入 RECAP.md 等新文件
- 主 agent merge 后全信任直接写入，不展示 diff
- PROJECT.md 不写项目名
- README 由 run 阶段子 agent 维护，不归 archive 管
- PROJECT.md 是导航不是详情，功能列表下沉到各模块 README
