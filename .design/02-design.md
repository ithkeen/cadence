# /cadence:design 设计（已定稿）

## 定位
基于已确认的需求，与用户聊清楚"怎么做"的技术方案，落到 `DESIGN.md`（给模型）+ `DESIGN.html`（给用户）。

明确不做：
- 不拆任务（plan 阶段做）
- 不写伪代码、不定函数名（plan/run 阶段做）
- 不重新讨论需求（如发现需求漏洞，打断让用户回 `/cadence:spec`）
- **不读源代码**（性能 + 上下文成本）
- 不向用户汇报"看到项目是什么栈、有什么模块"

## 调用形式
```
/cadence:design
```
不带参数。

## 项目现状的获取方式
**分层加载**：
1. 读 `.cadence/PROJECT.md` 拿到项目级地图（技术栈、模块清单、约定、决策）
2. 根据本次需求识别相关模块，按需读对应 `<module>/README.md` 拿模块详情
3. 不一次性读所有 README，按相关性挑

PROJECT.md 不存在 → 0-1 模式（视为空项目，不报错、不汇报）。

PROJECT.md 由 `/cadence:archive` 维护，README 由 `/cadence:run` 子 agent 维护，design 都不写。

## 执行流程
1. 读 `.cadence/CURRENT` 定位 cycle
2. 读 `cycle-<slug>/REQUIREMENT.md`
3. 读 `.cadence/PROJECT.md`（不存在则 0-1 模式）
4. 直接进入架构对话，不汇报现状
5. 按维度逐一追问（每轮 1~2 个）：
   - 技术选型
   - 模块划分
   - 数据模型
   - 接口设计
   - 关键流程
   - 非功能性约束
   - 风险与不确定项
6. 自检：
   - 每个"做什么"是否都有方案承接？
   - 每个不确定项是否明确"现在决定"还是"留到执行时再说"？
7. 留口："还有哪些地方想深入聊？"
8. 双写产出：
   - `DESIGN.md`：模块图（文字）、数据模型、接口列表、决策清单
   - `DESIGN.html`：Mermaid 架构图 + 卡片式模块/决策展示

## 0-1 模式 vs 项目档案模式

| | 0-1 模式 | 项目档案模式 |
|---|---|---|
| 起点 | 白板 | 已有架构 |
| 追问重点 | 整体技术栈选型 | 怎么贴合现状、不冲突 |
| 输出侧重 | 完整初始架构 | 增量改动 + 影响范围 |

主 agent 自动识别，不需要用户切换。

## HTML 渲染
Mermaid 通过 CDN 引入：
```html
<script type="module">
  import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
  mermaid.initialize({ startOnLoad: true });
</script>
```

## 调研建议机制
design 进行中，主 agent 识别到下列情况时**主动询问用户**是否调研：
- 涉及主 agent 不熟悉的技术栈
- 涉及多方案对比但主 agent 没把握说清取舍
- 涉及版本敏感的 API
- 涉及外部协议 / 集成

询问形态、调用方式、失败处理同 spec 阶段。
不触发场景：在已有代码上加功能、单纯新增函数、用户已把方案说清楚、常识性信息。

设计阶段也读 spec 阶段已落档的 research/ 文件作为上下文。

详见 05-subagents.md。

## 关键约束（用户明确表达过的偏好）
- 不读源代码
- 不向用户汇报"看到项目是什么"
- 不引入 bootstrap 命令；项目档案由 archive 维护
- HTML 用 CDN 渲染图，不本地化资源
