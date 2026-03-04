# RTS游戏交互系统 AI驱动需求与进度文档

版本：v1.0-ai  
日期：2026-03-04  
基线：`res://scenes/main/main.tscn` + `scripts/core/game_manager.gd` 当前实现  
对照文档：你提供的《RTS游戏交互系统需求文档(PRD v1.0, 2026-03-04)》

---

## 1. 文档目标

本文件用于把 PRD 转换为可执行研发清单，并给出当前项目的落地进度。

状态定义：

- `已实现`：功能在代码中可完整使用。
- `部分实现`：有基础能力，但不满足 PRD 关键约束或缺少可视化/边界处理。
- `未实现`：代码层尚未落地。

### 1.1 本轮实现更新（2026-03-04）

- 新增：[scripts/core/rts_command.gd](D:/Godot/projs/gd_rts/scripts/core/rts_command.gd)。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，接入输入状态机和命令执行队列。
- 改造：[scripts/units/unit.gd](D:/Godot/projs/gd_rts/scripts/units/unit.gd)，接入单位级命令排队执行。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，新增队列路径点可视化（数字标记 + 连线）与 `Alt+左键` 队列裁剪。
- 改造：[scripts/units/unit.gd](D:/Godot/projs/gd_rts/scripts/units/unit.gd)，新增单单位命令队列上限（默认32）和队列点数据导出接口。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，新增右键智能优先级链（攻击>采集>交付>跟随>集结点>移动）与重叠目标邻域判定。
- 改造：[scripts/buildings/building.gd](D:/Godot/projs/gd_rts/scripts/buildings/building.gd)，新增基础集结点数据接口（set/get rally）。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，新增生产完成后按集结点派发首条命令。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，建造模式支持 `R` 旋转（90度）与 `Shift+LMB` 连续放置。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，建造改为工人到位后开建（基础工期），无工人时回退为即时放置。
- 改造：[scripts/core/rts_catalog.gd](D:/Godot/projs/gd_rts/scripts/core/rts_catalog.gd)，补充 `placement_rotate` 指令定义。
- 改造：[scripts/buildings/building.gd](D:/Godot/projs/gd_rts/scripts/buildings/building.gd)，集结点数据扩展为最多3跳（兼容单跳接口）。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，支持建筑选择下 `Shift+RMB` 追加集结中继跳（最多3级）。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，新增集结点可视化（建筑到跳点连线 + 旗帜颜色标识）并接入上限反馈。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，新生产单位按多跳集结链顺序下达命令（后续跳点自动排队）。
- 修复：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，路径点连线角度改为按起终点动态对齐，并统一连线高度到路径点中心，修复“线段未完全连接”问题。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，集结点边界回退：目标失效/死亡/类型不匹配时自动降级为地面跳点。
- 改造：[scripts/buildings/building.gd](D:/Godot/projs/gd_rts/scripts/buildings/building.gd) + [scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，建筑受击时集结可视化闪烁警示（基础版）。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，集结旗帜增加模式字母标识（`M/G/A/F/R`）用于区分移动/采集/攻击/跟随/中继。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，新增集结设置反馈音（按模式不同音调，失败为错误音，程序生成WAV无需外部资源）。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，新增控制编组（`Ctrl+0~9` 设置、`Shift+0~9` 追加、`0~9` 选中、数字双击聚焦镜头）。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，新增异质单位子组切换（循环类型），并将单位指令下发限制到激活子组（当前快捷键为 `Tab`）。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，新增编组/子组 UI 提示与反馈音。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，新增同类双击选择（屏幕内）与 `Ctrl+双击` 全图同类选择（按精确单位类型）。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，新增编组设置地面反馈（单位/建筑头顶短时数字标识）。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，新增多选矩阵分页（`PgUp/PgDn`）与子组联动页签定位。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，新增 HUD 编组条数据下发与点击选组事件接入（QueueTopSpacer）。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，矩阵分页新增“按页码直达”事件（替代上一页/下一页）。
- 改造：[scripts/ui/rts_hud.gd](D:/Godot/projs/gd_rts/scripts/ui/rts_hud.gd)，多选矩阵对当前激活子组做高亮描边（子组UI联动基础版）。
- 改造：[scripts/ui/rts_hud.gd](D:/Godot/projs/gd_rts/scripts/ui/rts_hud.gd)，多选矩阵支持按单元类型高亮匹配（避免仅靠角色文案推断）。
- 调整：[scenes/ui/rts_hud.tscn](D:/Godot/projs/gd_rts/scenes/ui/rts_hud.tscn) + [scripts/ui/rts_hud.gd](D:/Godot/projs/gd_rts/scripts/ui/rts_hud.gd)，QueueTopSpacer 改为编组条（0-9 预置按钮），运行时仅更新透明度与文案。
- 调整：[scenes/ui/rts_hud.tscn](D:/Godot/projs/gd_rts/scenes/ui/rts_hud.tscn) + [scripts/ui/rts_hud.gd](D:/Godot/projs/gd_rts/scripts/ui/rts_hud.gd)，MatrixFooter 改为 MatrixGrid 左侧页码列（每页独立按钮）。
- 调整：[scenes/ui/rts_hud.tscn](D:/Godot/projs/gd_rts/scenes/ui/rts_hud.tscn) + [scripts/ui/rts_hud.gd](D:/Godot/projs/gd_rts/scripts/ui/rts_hud.gd)，MatrixFooter 宽度收敛为单按钮级，分页按钮统一固定宽度并按 `1..N` 直达。
- 修复：[scripts/ui/rts_hud.gd](D:/Godot/projs/gd_rts/scripts/ui/rts_hud.gd)，编组条间距改为 `add_theme_constant_override`，修复 `HBoxContainer.theme_override_constants` 运行时报错。
- 调整：[scripts/ui/rts_hud.gd](D:/Godot/projs/gd_rts/scripts/ui/rts_hud.gd) + [scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，矩阵格子交互改为选择语义：`LMB` 单独选中该格对象、`Shift+LMB` 选中当前选择内同类型、`Ctrl+LMB` 从当前选择剔除该格对象；子组循环快捷键改为 `Tab`。
- 修复：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，修正多选同类型分页在状态刷新时被重置到第一页的问题（子组状态刷新不再每帧强制清零分页）。
- 修复：[scripts/ui/rts_hud.gd](D:/Godot/projs/gd_rts/scripts/ui/rts_hud.gd)，QueueTopSpacer/ControlGroupBar 透明容器改为鼠标穿透，恢复透明区域内框选响应。
- 新增：[RTS_Worker_Construction_TaskPlan.md](D:/Godot/projs/gd_rts/docs/RTS_Worker_Construction_TaskPlan.md)，基于 Worker Construction System v1.2 的实施任务分解与进度看板。

### 1.2 本轮输入路径测试清单（待编辑器内验证）

1. 仅选生产建筑，`RMB` 地面：设置单跳地面集结，显示黄色旗帜与连线。
2. 仅选生产建筑，`Shift+RMB` 连续点3次不同目标：形成3跳中继，显示多段连线与编号旗帜。
3. 在已有3跳时继续 `Shift+RMB`：应拒绝并出现“relay已满”提示。
4. 设置资源/敌方/友方单位为集结目标后训练单位：新单位应按模式执行首跳，并按后续跳点排队。
5. 混合选择单位+建筑后 `RMB`：应优先按单位智能指令，不进入建筑集结设置。
6. 下达多段移动队列后检查路径点连线：每段应朝向实际下一点并与路径点中心连续连接。
7. 仅选生产建筑后设置不同类型集结点：旗帜应显示 `M/G/A/F/R` 对应字母，且播放不同确认音；超上限应播放错误音。
8. 选中多单位后按 `Ctrl+1`：应设置编组1，再按 `1` 应恢复选中，再次快速按 `1` 镜头应跳到该编组中心。
9. 编组追加：已有编组1时，另选单位按 `Shift+1`，再次按 `1` 应包含追加单位且不丢旧成员。
10. 混合单位类型（如工人+士兵）按 `Tab`：应循环子组，后续移动/攻击/停止仅作用于当前激活子组。
11. 双击单位：应选中屏幕内同类型单位；`Ctrl+双击` 应选中全图同类型单位。
12. 子组切换后 HUD 多选矩阵：当前子组对应的单位格子边框应高亮。
13. 选中单位后按 `Ctrl+数字`/`Shift+数字`：对应单位/建筑头顶应短时显示该数字标识。
14. 多选数量超过24时按 `PgUp/PgDn`：多选矩阵应切页；`Tab` 切子组时应自动跳到该子组所在页。
15. 多选矩阵格子交互：`LMB` 仅保留该格对象，`Shift+LMB` 仅保留同类型对象，`Ctrl+LMB` 从当前选择剔除该格对象。
16. QueueTopSpacer 编组条：仅已有编组的按钮显示不透明（其余透明占位）；点击某数字按钮应选中对应编组。
17. 多选矩阵分页：当页数 `<=1` 隐藏左侧分页列；当页数 `>1` 显示每一页独立按钮（1..N），点击后直达该页。
18. MatrixFooter 布局：应位于 MatrixGrid 左侧，宽度接近一个普通按钮宽度，不再显示 `prev/next`。
19. 选中大量同类型单位并切到第2页及以后：在无选择变更的状态刷新过程中，分页不应自动跳回第1页。
20. 在 QueueTopSpacer 的透明区域（非按钮）按住左键拖拽：应正常触发框选，不被透明控件拦截。

---

## 2. 当前项目学习结论（代码基线）

### 2.1 已有可用能力

- 选择：单选、框选、`Shift` 叠加选择。
- 指令：右键上下文（采集/攻击/移动），`A` 进入攻击目标模式，`S` 停止。
- 资源循环：采集 -> 回收 -> 入账。
- 建造：进入放置模式，预览合法性着色，支持旋转与连续放置；优先由工人到位后开建（无工人时回退即时生成）。
- 生产：基地/兵营支持训练队列，HUD 显示队列与进度。
- 战斗：士兵攻击/攻击移动，塔自动攻击。
- AI：敌方定时训练与波次进攻。
- 新增基础命令框架：`RTSCommand` 数据结构 + `game_manager` 执行队列。
- 新增基础状态机：`IDLE / UNIT_SELECTED / SKILL_SELECTED / BUILDING_PLACEMENT / QUEUE_INPUT`。
- 新增单位命令队列：`unit.submit_command()` 支持即时执行与排队执行。

### 2.2 当前关键限制

- Command 对象与执行队列已落地基础版，但仍未拆出独立 `Input Parser / Context Analyzer` 模块。
- 全局状态机已落地基础版，但仍缺迁移图和完整事件驱动流转约束。
- 右键智能判定链已落地基础版（含交付、跟随、集结点）；仍缺“按住右键预览、维修/治疗分支、错误音效”。
- 单位命令队列已支持基础排队、路径点可视化、上限控制、`Alt+LMB` 删除后续；仍缺插入编辑（`Ctrl+Shift+LMB`）与更完整规则。
- 集结点已支持多跳中继（最多3跳）、基础可视化、受击闪烁警示、目标失效地面回退、模式字母旗帜与基础提示音；仍缺专业图标资源与更完整音效体系。
- 已有编组、子组、同类双击、编组数字地标；HUD层已调整为“QueueTopSpacer 编组条 + Matrix 左侧页码列”，后续可继续打磨图标与视觉风格。
- 无光标状态机、范围圈、音效反馈、网络预测回滚。

---

## 3. PRD覆盖进度矩阵


| PRD模块         | 状态   | 当前实现                                                                     | 主要差距                                        |
| ------------- | ---- | ------------------------------------------------------------------------ | ------------------------------------------- |
| 3.1 指令层级结构    | 部分实现 | 已有 Command 对象与 Execution Queue（基础）                                       | 仍缺独立 Input Parser / Context Analyzer 模块拆分   |
| 3.2 全局状态机     | 部分实现 | 已有 5 态基础状态机并按输入刷新                                                        | 仍缺完整状态迁移事件图与网络态同步                           |
| 4.1.1 鼠标映射    | 部分实现 | 左键单击/拖拽、右键上下文、ESC取消                                                      | 缺方向性框选规则、`Shift+右键`队列、ESC清空选择策略             |
| 4.1.2 键盘快捷键   | 部分实现 | `A/S/B/R/T/ESC` 可用（建造模式下 `R` 旋转）                                         | 缺 `M/H/P`                                   |
| 4.2 技能系统      | 部分实现 | 地面/单位目标、无指向技能（停止/返回）基础可用                                                 | 缺方向技能、自动施法、范围预览、前摇/引导取消回溯                   |
| 4.3 智能右键      | 部分实现 | 已支持攻击/采集/交付/跟随/集结点/移动优先级，并做邻域冲突判定                                        | 缺按住右键悬停预览、维修/治疗分支、非法目标音画反馈                  |
| 4.4 建造放置      | 部分实现 | 已支持虚影预览、合法红绿、旋转、连续放置、工人到位后开建（基础版）                                        | 缺间距数值、范围圈、建造中断策略与多建造者加速规则                   |
| 4.5 集结点系统     | 部分实现 | 已支持生产建筑RMB设置集结（地面/资源/攻击/跟随/中继），`Shift+RMB` 追加最多3跳，并在出生后按跳点顺序执行；含连线+旗帜可视化、受击闪烁、目标失效回退、`M/G/A/F/R` 字母标识与基础提示音 | 缺专业图标资源与更完整音效体系                      |
| 4.6 命令队列系统    | 部分实现 | 已支持单位命令排队 + 路径点编号可视化 + 队列上限32 + Alt删除后续                                  | 缺 Ctrl+Shift插入编辑、完整混合编辑规则与UI层队列面板联动         |
| 4.7 选中与群组     | 部分实现 | 已支持单选/框选/混选基础 + 控制编组（设置/追加/选中/双击聚焦）+ 编组数字地标 + QueueTopSpacer 编组条点击选组 + `Tab` 子组循环与子组指令控制 + 双击同类/`Ctrl+双击` 全图同类 + 子组矩阵高亮 + 多选分页（PgUp/PgDn + 左侧页码按钮） + 矩阵格子选择语义（LMB/Shift/Ctrl） | 仍缺“头像化”美术展示（功能非阻塞） |
| 5 视觉与反馈规范     | 部分实现 | 选择框、选中圈、建造虚影着色、HUD提示                                                     | 缺光标状态表、施法/射程范围圈、指令音效                        |
| 6 边界与异常处理     | 部分实现 | 目标失效后部分回退、资源与训练前置检查                                                      | 缺资源枯竭自动换矿、卡死重算、网络预测回滚                       |
| 7 配置化参数       | 部分实现 | 已有一部分常量和导出变量                                                             | 缺 PRD 参数全集与统一配置入口                           |
| 8 Command数据结构 | 部分实现 | 已落地 `RTSCommand` 基础字段与工厂函数                                               | 仍缺 `Direction/ControlGroup/SubGroup` 全量业务接入 |


---

## 4. 量化进度（对PRD v1.0）


| 子系统      | 权重  | 完成度 | 加权得分  |
| -------- | --- | --- | ----- |
| 输入与状态机   | 20% | 60% | 12.0% |
| 智能右键系统   | 15% | 55% | 8.25% |
| 技能交互系统   | 20% | 20% | 4.0%  |
| 建造放置系统   | 15% | 50% | 7.5%  |
| 集结点+命令队列 | 15% | 72% | 10.8%  |
| 选中/群组/编组 | 10% | 80% | 8.0%  |
| 反馈/边界/配置 | 5%  | 42% | 2.1%  |


**整体进度估算：52.65%**

---

## 5. AI驱动实施路线（里程碑）

### M1：命令框架重构（P0）

目标：把当前“直接调用方法”改为“可扩展命令管线”。
当前状态：已完成基础版（Command对象 + 执行队列 + 基础状态机已接入）。

交付物：

- `Command` 数据结构（类型、目标、队列标记、时间戳）。
- `Input Parser` + `Context Analyzer` + `Command Generator` 基础分层。
- `Execution Queue`（支持立即执行与排队执行）。
- 全局状态机最小集：`IDLE/UNIT_SELECTED/SKILL_SELECTED/BUILDING_PLACEMENT/QUEUE_INPUT`。

验收标准：

- 现有 move/attack/gather/stop/build 流程不回归。
- `Shift` 下达命令进入队列，不按 `Shift` 立即执行。

### M2：智能右键与目标预览（P0）

目标：实现 PRD 4.3 的严格优先级与可预判交互。

交付物：

- 右键优先级链：攻击 > 采集 > 交付 > 跟随 > 维修/治疗 > 集结点 > 移动。
- 按住右键悬停预览图标，松手执行。
- 重叠目标冲突解算（敌方 > 资源 > 友方 > 地面）。

验收标准：

- 同坐标叠放资源+单位时，行为稳定且可复现。
- 目标非法时仅提示，不产生脏命令。

### M3：技能系统与可视化（P0）

目标：补齐点目标/单位目标/方向技能基础框架。

交付物：

- 统一目标模式：`Point / Unit / Direction / None`。
- 施法范围圈、AOE圈、非法目标高亮、方向箭头。
- 技能取消窗口与目标丢失回退逻辑。

验收标准：

- 任意技能状态可通过 `RMB/ESC` 无损退出。
- 目标死亡/失效不导致卡状态。

### M4：建造/集结点/命令队列（P1）

目标：落地生产向 RTS 核心交互。

交付物：

- 建造旋转、连续建造、建造者到位开建。
- 集结点类型与最多3跳中继。
- 队列点位可视化、混合命令队列、基础编辑（删除后续）。

验收标准：

- 新生产单位可按集结类型自动执行首个动作。
- 队列上限触发时有明确拒绝反馈。

### M5：群组控制与反馈完善（P1）

目标：提升高 APM 操作体验。

交付物：

- 双击同类、Ctrl双击全图同类、Ctrl+数字编组、数字双击镜头跳转。
- 子组切换（Tab）。
- 光标状态机、指令音效、错误音效。

验收标准：

- 常用 RTS 竞速操作链路可在 1-2 次点击内完成。

---

## 6. AI任务看板（首轮）


| ID    | 任务                     | 优先级 | 状态       | 说明                                                |
| ----- | ---------------------- | --- | -------- | ------------------------------------------------- |
| A-001 | 现状基线扫描与PRD映射           | P0  | 已完成      | 本文档即输出                                            |
| A-002 | 定义 `Command` 数据结构与执行入口 | P0  | 已完成      | `scripts/core/rts_command.gd` + 执行队列已接入           |
| A-003 | 引入全局状态机与状态迁移图          | P0  | 已完成      | 5态状态机已接入，迁移图文档待补                                  |
| A-004 | `Shift` 队列下达与基础可视化     | P0  | 已完成（基础版） | 已支持路径点数字标记/连线、上限32、Alt删除后续                        |
| A-005 | 智能右键优先级链               | P0  | 已完成（基础版） | 已接入优先级链与邻域冲突判定，预览与维修分支待补                          |
| A-006 | 建造旋转与连续建造              | P1  | 已完成（基础版） | 已支持旋转/连续放置/工人到位开建；高级规则后续在边界项补齐                    |
| A-007 | 集结点系统（地面/资源/攻击）        | P1  | 进行中（增强版） | 已支持3跳中继、`Shift+RMB` 追加、连线旗帜可视化、受击闪烁、目标失效回退、`M/G/A/F/R` 字母标识、基础提示音与出生按链执行，待补专业图标资源与更完整音效 |
| A-008 | 控制编组与子组切换              | P1  | 已完成（增强版） | 已支持 Ctrl设组/Shift追加/数字选组与双击聚焦，已支持编组数字地标与 QueueTopSpacer 编组条点击选组，已支持 Tab 子组轮换与子组指令控制，已支持双击同类/`Ctrl+双击` 全图同类、子组矩阵高亮、PgUp/PgDn 多选分页与左侧页码按钮直达，并支持矩阵格子 LMB/Shift/Ctrl 三态选择 |
| A-009 | 队列插入编辑（Ctrl+Shift+LMB） | P1  | Hold     | 依据当前指令，暂缓实现                                       |


---

## 7. 建议的实现顺序（务实版）

1. 先补 `A-007` 收尾：接入正式图标资源（矿/剑/盾/中继）与分层音效（确认/错误/警示）。
2. 然后补齐 `A-005` 剩余项（右键按住预览、维修/治疗分支、非法反馈音效）。
3. 最后回补 `A-009`（当前 Hold）：队列插入编辑（`Ctrl+Shift+LMB`）。

---

## 8. 后续维护规则（AI协同）

- 每完成一个任务，更新本文件的“状态 + 验收结果 + 关联脚本”。
- 所有交互改动都要补“输入路径测试清单”（键盘、鼠标、取消分支）。
- 状态机与命令结构变更时，先更新文档再改代码，保持规格同步。
