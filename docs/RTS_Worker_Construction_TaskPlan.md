# RTS 农民建造系统任务规划文档

版本：v1.0-plan  
日期：2026-03-04  
输入基线：`RTS 农民建造系统需求文档 (Worker Construction System) v1.2`  
当前代码基线：`scripts/core/game_manager.gd` + `scripts/units/unit.gd` + `scripts/buildings/building.gd` + `scripts/core/rts_catalog.gd`

---

## 1. 目标与范围

目标：将当前“放置后扣费 + 农民到位后直接生成建筑”的基础建造，升级为 PRD v1.2 定义的完整农民建造系统：

- Ghost 生命周期完整受控（Ghost Phase / Pending Ghost / Site / Completed）。
- 支持三种建造范式：A 召唤型、B 驻守型、C 献祭型。
- 统一取消建造层级与 75% 返还规则。
- 自动采集循环与 Shift 队列互操作。
- 建筑/农民选中时指令面板按状态切换。

非目标（本轮不做或降级做）：

- 网络同步（当前项目单机为主）。
- 完整存档系统接入（当前代码中无统一 save/load 框架）。
- 高复杂美术资源替换（先用程序化/占位视觉）。

### 1.1 本轮实施更新（2026-03-04）

- 改造：[scripts/core/rts_catalog.gd](D:/Godot/projs/gd_rts/scripts/core/rts_catalog.gd)，为建筑定义补充 `construction_paradigm`、`build_time`、`cancel_refund_ratio`。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，新增 Pending Ghost 数据与可视层（`_pending_construction_ghosts` + `PendingConstructionGhosts` root）。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，建造确认改为“先创建 Pending Ghost + 下达农民到位”，扣费后移到到位开工瞬间。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，资源不足到位时进入红色闪烁等待并每3秒重试资源检查。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，落地 Ghost 基础清理触发：`Stop`、冲突覆盖命令、农民死亡/失效、`ESC` 手动取消（当前对选中农民生效）。
- 改造：[scripts/buildings/building.gd](D:/Godot/projs/gd_rts/scripts/buildings/building.gd)，新增 Construction Site 状态机（施工中/暂停/完成）、动态施工命令卡（Exit/Cancel/Select Worker）与 `construction_state_changed` 信号。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，Pending Build 改为“到位即生成 Site，Site 自推进”，并接入 `construction_exit / construction_cancel_destroy / construction_select_worker / construction_cancel_eject` 命令分发。
- 改造：[scripts/units/unit.gd](D:/Godot/projs/gd_rts/scripts/units/unit.gd)，新增建造锁定模式（Garrisoned/Incorporated）、驻守期默认队列化（近似默认 Shift）与献祭期隐藏/重现。
- 改造：[scripts/core/rts_catalog.gd](D:/Godot/projs/gd_rts/scripts/core/rts_catalog.gd)，新增施工期命令定义（Exit/CancelDestroy/CancelEject/SelectWorker）。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd) + [scripts/buildings/building.gd](D:/Godot/projs/gd_rts/scripts/buildings/building.gd)，接入建造中建筑被摧毁后的工人释放；献祭型按 50%HP 惩罚释放（基础版）。
- 改造：[scripts/buildings/building.gd](D:/Godot/projs/gd_rts/scripts/buildings/building.gd) + [scripts/units/unit.gd](D:/Godot/projs/gd_rts/scripts/units/unit.gd) + [scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，新增 A 范式施法阶段（Cast）与工人硬锁；施法完成后自动释放工人进入 Auto-Build 阶段。
- 改造：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，新增“暂停的驻守型 Site”右键智能恢复建造（`resume_construction`），并加入挂单轮询与到点恢复绑定。
- 修复：[scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，统一把恢复建造挂单纳入 Stop/覆盖命令取消链，避免恢复订单残留或重复派单。
- 改造：[scripts/units/unit.gd](D:/Godot/projs/gd_rts/scripts/units/unit.gd) + [scripts/core/game_manager.gd](D:/Godot/projs/gd_rts/scripts/core/game_manager.gd)，新增工人采集循环与 Shift 队列交互断点：采集中/回收中可延迟到资源状态节点切换队列；前往采集点途中支持立即切出执行队列，并提供“工作中断”HUD提示（基础版）。

---

## 2. 当前基线学习结论（针对建造链路）

### 2.1 已有能力

- `game_manager` 已支持建造放置预览、合法性校验、旋转、连续放置。
- 目前建造确认后立即扣费（`_confirm_building_placement`），若有农民则进入 `_pending_build_orders`。
- `_pending_build_orders` 中农民到位后计时，完成后直接 `_spawn_building_instance`。
- 无独立 Ghost 对象、无 Construction Site 中间状态。
- `unit.gd` 已有命令队列、采集/回收循环与 Stop 语义。
- `building.gd` 目前聚焦生产与战斗，不含“建造中状态机/驻守/献祭”语义。
- `rts_catalog.gd` 已有建筑定义和建造技能，但无 `construction_paradigm` 配置。

### 2.2 核心差距

- Ghost 生命周期缺失（生成/清理触发器不完整）。
- 扣费时机与 PRD 不符（应在农民到达 Site 生成瞬间二次检查并扣费）。
- 无 Site 状态机（暂停、取消、完成、销毁、返还规则）。
- 无 A/B/C 范式差异逻辑。
- 无驻守型“默认 Shift 模式”与“仅取消建造可退出”逻辑。
- 无献祭型“农民内部化/取消释放/被毁逃生”逻辑。
- 无状态化命令卡（Worker/Site 的状态专属按钮）。

---

## 3. 需求映射与优先级矩阵

| 模块 | PRD要求 | 当前状态 | 优先级 |
|---|---|---|---|
| 生命周期 | Ghost -> Pending Ghost -> Site -> Completed | 仅放置预览 + 直接建造订单 | P0 |
| Ghost 管理 | 生成/销毁触发器完整 | 未实现 | P0 |
| 扣费时机 | 到达 Site 时检查并扣费 | 当前在左键确认时扣费 | P0 |
| 范式 A/B/C | 三种建造范式 + 差异化取消 | 未实现 | P0 |
| 取消层级 | Exit / Cancel&Destroy / 被毁 | 未实现（仅间接中断） | P0 |
| 返还规则 | 主动取消统一 75% | 未实现 | P0 |
| 自动采集+Shift | 采集循环断开节点 + 队列接续 | 部分（有采集循环、无断开机制） | P1 |
| 命令卡与选中 | Worker/Site/Building 状态化按钮 | 部分（通用命令卡） | P1 |
| 边界控制 | 资源不足重试、控制效果、献祭逃生 | 未实现 | P1 |
| 存档一致性 | C范式 worker 数据序列化 | 现阶段无存档框架 | P2 |

---

## 4. 目标架构（落地到当前工程）

### 4.1 新数据对象（建议）

1. `PendingConstructionGhost`（建议放 `game_manager.gd` 内部结构，后续可抽独立脚本）
- 字段：`worker_path`, `position`, `building_kind`, `paradigm`, `is_queued`, `created_at`, `status`。
- 可选：`ghost_node_path`（对应场景可视节点）。

2. `ConstructionSiteState`（建议放 `building.gd`）
- `NONE / PENDING / SUMMONING / GARRISONED / INCORPORATED / AUTO_BUILD / PAUSED / COMPLETED / DESTROYED`
- 绑定字段：`assigned_worker_path`, `paradigm`, `build_progress`, `build_duration`, `is_under_construction`。

3. 配置补充（`rts_catalog.gd`）
- `construction_paradigm`：`summoning|garrisoned|incorporated`
- `build_time`
- `cancel_refund_ratio`（默认 0.75）
- `incorporated_eject_stun_sec`、`incorporated_destroy_hp_penalty`

### 4.2 关键流程改造

1. 左键确认建造：
- 不再立即扣费。
- 生成 Pending Ghost，挂到该 worker 的 pending 列表。

2. worker 到达 ghost：
- 二次检查资源；成功则扣费并生成 Site；失败则 ghost 进入红闪重试态（每3秒）。

3. Site 按范式推进：
- A：施法锁定 -> 释放 worker -> 建筑自建。
- B：worker 驻守，默认 Shift 追加，Exit 可暂停。
- C：worker 内部化，只能建筑界面 Cancel&Eject。

4. 取消体系：
- Exit（B）：0%返还，保留进度。
- Cancel&Destroy（A/B/C）：75%返还。
- 被敌方摧毁：0%返还，按范式处理 worker。

---

## 5. 任务分解（Backlog）

### M1：基础状态机与 Ghost（P0）

- `WCS-001` 在 `rts_catalog.gd` 增加建造范式与建造参数配置。  
状态：`Done`
- `WCS-002` 在 `game_manager.gd` 引入 `pending_construction_ghosts` 数据结构与增删改查。  
状态：`Done`
- `WCS-003` 把 `_confirm_building_placement` 改为“生成 Pending Ghost + 下达到位命令”，移除即时扣费。  
状态：`Done`
- `WCS-004` 增加 Ghost 可视节点（至少支持 pending/invalid 两种表现与清理特效）。  
状态：`Done (基础版)`
- `WCS-005` 落地 Ghost 清理触发器：Stop、覆盖指令、worker死亡、ESC/取消。  
状态：`Done (基础版)`

验收（M1）：
- 仅左键确认不扣费。
- worker 到达前可看到固定 Pending Ghost。
- 任何冲突指令会清掉对应 ghost。

### M2：Site 与取消层级（P0）

- `WCS-006` 在 `building.gd` 新增建造中状态字段与 Site 进度推进。  
状态：`Done`
- `WCS-007` 增加 `cancel_construction_and_destroy()` 与统一 75% 返还。  
状态：`Done`
- `WCS-008` 增加 B 范式 `exit_construction()`（暂停保留进度，0%返还）。  
状态：`Done (基础版，含右键恢复建造)`
- `WCS-009` 在 `game_manager.gd` 接入“敌方摧毁=0%返还”的强制摧毁分支。  
状态：`Done (基础版)`

验收（M2）：
- 三层取消路径均可触发，返还规则正确。
- B 范式可暂停并后续继续。

### M3：三范式行为（P0）

- `WCS-010` A 范式：施法阶段锁定 + 自动建造阶段可取消。  
状态：`Done (基础版)`
- `WCS-011` B 范式：worker 驻守锁定；普通指令自动视为队列追加到建造完成后。  
状态：`Done (基础版)`
- `WCS-012` C 范式：worker 内部化（不可选中）；Cancel&Eject 释放 + 75%返还。  
状态：`Done (基础版)`
- `WCS-013` C 范式建筑被毁：worker重现 + 50%HP 惩罚。  
状态：`Done (基础版)`

验收（M3）：
- A/B/C 三种行为可在同局并行复现。
- 取消/被毁后 worker 状态符合范式定义。

### M4：采集循环与队列交互（P1）

- `WCS-014` `unit.gd` 增加“采集循环断开点”机制：采集中/回收中完成节点后切换到玩家队列。  
状态：`Done (基础版)`
- `WCS-015` 在 `game_manager.gd` 下达 Shift 队列时，为采集worker写入“待中断标记”。  
状态：`Done (基础版，unit内持有中断标记)`
- `WCS-016` 增加“工作中断”HUD提示与队列标记更新。  
状态：`Done (基础版，HUD文案提示已接入)`

验收（M4）：
- 正在采集/回收时 Shift 指令不会丢资源。
- 回收完成后自动切到新队列。

### M5：命令卡、选中逻辑与边界（P1）

- `WCS-017` 命令卡状态化：
  - Idle worker：标准指令；
  - B驻守worker：仅 Exit；
  - A/B/C 建造中建筑：对应取消按钮与“选中驻守单位”。  
状态：`Todo`
- `WCS-018` 快速选中“驻守单位”按钮的镜头策略（屏内切换，屏外平滑拉镜头）。  
状态：`Todo`
- `WCS-019` 资源不足到达 Site：红闪 + 每3秒重试。  
状态：`Todo`
- `WCS-020` 控制效果（眩晕/击退/魅惑）对 B 范式的暂停/恢复策略。  
状态：`Todo`

验收（M5）：
- 命令卡与选中对象状态一致。
- 资源不足重试与提示可复现。

### M6：存档与一致性（P2）

- `WCS-021` 若未来接入存档：C 范式内部 worker 完整序列化/反序列化。  
状态：`Deferred`

---

## 6. 文件落地映射（实现责任）

- `scripts/core/game_manager.gd`
  - Ghost 队列管理
  - placement -> ghost -> site 主流程
  - 取消指令入口、资源二次检查、HUD通知
- `scripts/buildings/building.gd`
  - ConstructionSite 状态机
  - A/B/C 范式推进与取消 API
- `scripts/units/unit.gd`
  - 采集循环断开点
  - B 范式驻守状态下的“默认 Shift”语义支持
- `scripts/core/rts_catalog.gd`
  - 建筑建造范式与参数配置
  - 新技能定义（Exit/Cancel&Eject/SelectWorker）
- `scripts/core/rts_command.gd`
  - 视实现需要扩展命令类型（如 `CANCEL_CONSTRUCTION`, `SELECT_CONSTRUCTION_WORKER`）
- `scripts/ui/rts_hud.gd` + `scenes/ui/rts_hud.tscn`
  - 指令面板动态按钮、Shift模式视觉提示、Tooltip 提示
- 可选新增：
  - `scenes/buildings/construction_ghost.tscn`
  - `scripts/buildings/construction_ghost.gd`

---

## 7. 验收测试清单（首版）

1. 放置建筑后未到达前，不扣费；出现 Pending Ghost。  
2. worker 到达后才扣费并转 Site；Ghost 消失。  
3. Stop/新指令/worker死亡/ESC 均可清理未到达 Ghost。  
4. A 范式施法完成后 worker 释放；自动建造可取消并返还75%。  
5. B 范式选中 worker 仅见 Exit；普通指令自动排队到建造完成后。  
6. B 范式 Exit 后建筑暂停、0%返还，可恢复。  
7. C 范式 worker 不可直接选中；Cancel&Eject 释放并返还75%。  
8. C 范式建筑被摧毁，worker 重现且 HP 下降至 50%。  
9. 采集中/回收中收到 Shift 指令，资源不会丢失，节点后切队列。  
10. 资源不足到达 Site 时进入红闪并每3秒重试，资源满足后继续。  

---

## 8. 风险与决策点

1. **范式配置粒度**：按建筑类型固定，还是按建造技能动态覆盖。建议先“按建筑类型固定”。
2. **C范式内部 worker 表示**：建议先用“隐藏原单位 + 数据快照”，后续再替换为真正脱离世界实体。
3. **B范式默认 Shift 实现方式**：建议在 `game_manager` 下发命令时进行状态拦截，不改底层命令格式。
4. **资源返还一致性**：统一入口在 `game_manager`，避免 `building.gd`/`unit.gd` 双处返还导致重复加矿。
5. **存档条款（PRD 8.3）**：当前无存档框架，先标记为 `P2 Deferred`。

---

## 9. 建议执行顺序（实装顺序）

1. 先做 `M1 + M2`，把 Ghost + Site + 取消返还闭环打通。  
2. 再做 `M3`，把 A/B/C 差异跑通。  
3. 再做 `M4 + M5`，补操作手感与边界。  
4. 最后评估 `M6` 是否需要随存档系统一起进入主线。

---

## 10. 进度看板模板（供后续续写）

| ID | 任务 | 优先级 | 状态 | 关联文件 |
|---|---|---|---|---|
| WCS-001 | Catalog 增加建造范式配置 | P0 | Done | `rts_catalog.gd` |
| WCS-002 | Pending Ghost 数据结构 | P0 | Done | `game_manager.gd` |
| WCS-003 | placement 扣费时机改造 | P0 | Done | `game_manager.gd` |
| WCS-004 | Ghost 可视节点与状态 | P0 | Done (基础版) | `game_manager.gd` |
| WCS-005 | Ghost 生命周期清理触发器 | P0 | Done (基础版) | `game_manager.gd` |
| WCS-006~009 | Site/取消层级/强制摧毁分支 | P0 | Done (基础版) | `building.gd` + `game_manager.gd` |
| WCS-010~013 | 三范式细节深化 | P0 | Done (基础版) | `building.gd` + `game_manager.gd` + `unit.gd` |
| WCS-014~016 | 采集循环 + Shift 队列 | P1 | Done (基础版) | `unit.gd` + `game_manager.gd` |
| WCS-017~020 | UI与边界规则 | P1 | Todo | `rts_hud.gd` + 相关核心脚本 |
| WCS-021 | 存档一致性 | P2 | Deferred | （待存档框架） |
