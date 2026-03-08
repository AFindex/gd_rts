# RTS Godot UI 实现细节与要求（代码基线）

日期：2026-03-08  
范围：`scenes/main/main.tscn`、`scenes/ui/rts_hud.tscn`、`scripts/ui/*.gd`、`scripts/core/game_manager.gd`

---

## 1. 结论摘要

当前 UI 是一套 **CanvasLayer + RTSHud + SelectionOverlay** 的 Godot 运行时 HUD 系统，核心特点是：

- HUD 结构固定（顶部信息带 + 底部四区块 + 通知区）。
- 底部布局已从容器流式布局迁移为脚本手动布局（参数可调）。
- 交互链路完整：命令卡、编组条、多选矩阵分页、小地图导航与 Ping、框选覆盖层。
- `game_manager.gd` 与 `rts_hud.gd` 通过 `snapshot + signals` 形成明确数据契约。

---

## 2. UI 架构总览

## 2.1 场景挂载关系

- 主场景：`Main(Node3D)` 挂载 `scripts/core/game_manager.gd`
- UI 根：`Main/UI(CanvasLayer)`
- UI 子节点：
  - `SelectionOverlay(Control)` -> `scripts/ui/selection_overlay.gd`
  - `RTSHud(instance)` -> `scenes/ui/rts_hud.tscn`（脚本 `scripts/ui/rts_hud.gd`）

`game_manager.gd` 通过导出路径绑定：

- `selection_overlay_path = UI/SelectionOverlay`
- `hud_path = UI/RTSHud`

## 2.2 UI 与核心逻辑连接方式

- `game_manager -> hud`：调用
  - `update_hud(snapshot)`
  - `update_minimap(snapshot)`
- `hud -> game_manager`：信号回调
  - `command_pressed`
  - `multi_role_cell_pressed`
  - `control_group_pressed`
  - `matrix_page_selected`
  - `minimap_navigate_requested`
  - `ping_button_pressed`
  - `ping_requested`

---

## 3. 各 UI 模块实现细节

## 3.1 选择框覆盖层（SelectionOverlay）

文件：`scripts/ui/selection_overlay.gd`

- 类型：`Control`，全屏锚定，`mouse_filter = IGNORE`。
- 提供接口：
  - `begin_drag(screen_pos)`
  - `update_drag(screen_pos)`
  - `end_drag()`
  - `get_selection_rect()`
- 渲染：半透明填充 + 描边矩形。
- 输入来源：由 `game_manager` 在 LMB 拖拽流程中驱动调用。

## 3.2 主 HUD（RTSHud）

文件：`scenes/ui/rts_hud.tscn` + `scripts/ui/rts_hud.gd`

### 3.2.1 结构分区

- `TopBar`
  - `ResourcePanel`
  - `CenterTop`
  - `SystemPanel`
- `BottomHUD/BottomRow`
  - `SelectionPanel`
  - `QueueColumn`
  - `PortraitColumn`
  - `CommandColumn`
- `NotificationPanel`

### 3.2.2 动态创建与缓存

`_ready()` 内构建/缓存：

- 队列槽位（5）
- 命令格（20，实例化 `skill_command_item.tscn`）
- 多选矩阵格（30）
- 控制组按钮缓存（0-9）
- 施工状态 UI 子树（运行时创建）
- 单体状态图标占位（运行时创建）

### 3.2.3 布局系统

采用参数化手动布局，关键导出参数包括：

- 顶部：`use_manual_top_layout`, `manual_top_section_ratios`, `manual_top_gap`
- 底部：`use_manual_bottom_layout`, `manual_bottom_section_ratios`, `manual_bottom_gap`
- 子区：Queue/Portrait/Command/Matrix/CommandGrid 等专用参数

关键机制：

- 触发刷新：`_request_manual_bottom_layout_refresh()`
- 防抖：`_manual_layout_refresh_pending + call_deferred`
- 重入保护：`_is_applying_manual_layout`
- 首帧稳定：`_manual_layout_warmup_frames = 3`
- 窗口变化：`NOTIFICATION_RESIZED` 触发重排

### 3.2.4 HUD 模式状态

`update_hud(snapshot)` 依据 `mode` 切换：

- `none`：无选择
- `single`：单选（单位/建筑）
- `multi`：多选矩阵模式

单选支持两种生产显示：

- `production_mode = "queue"`：普通队列
- `production_mode = "construction"`：施工进度行（图标 + 标题 + 进度）

### 3.2.5 交互组件

- 命令卡：点击发 `command_pressed`，hover 显示固定悬浮面板。
- 控制组条：动态显示非空编组，点击发 `control_group_pressed`。
- 多选矩阵：单元格 LMB/Shift/Ctrl 语义通过 `multi_role_cell_pressed` 上报。
- 分页按钮：仅多页时显示，点击发 `matrix_page_selected`。
- 小地图区域：连接导航与 ping 信号。

## 3.3 命令格组件（SkillCommandItem）

文件：`scenes/ui/skill_command_item.tscn` + `scripts/ui/skill_command_item.gd`

- 输入数据：`apply_entry(entry: Dictionary)`
- 关键字段：
  - `id`, `label`, `hotkey`, `cost_text`, `detail_text`, `icon_path`
  - `enabled`, `cooldown_ratio`, `disabled_reason`
- 行为：
  - 点击发 `pressed(command_id)`
  - hover 发 `hover_started(hover_data)` / `hover_ended`
  - 无 icon 时使用首字母 fallback glyph
  - disabled mask + cooldown mask 覆盖层

## 3.4 小地图视图（RtsMinimapView）

文件：`scripts/ui/rts_minimap_view.gd`

- 纯 `Control._draw()` 绘制：
  - 背景/网格
  - 资源点
  - 建筑点
  - 单位点
  - 相机视口框
  - Ping 脉冲
- 输入：
  - LMB：导航或发 ping（取决于 ping 模式）
  - LMB 拖拽：连续导航
- 坐标：
  - 使用 `map_half_size` 做 world(x,z) <-> minimap(u,v) 双向转换
- 信号：
  - `navigate_requested(world_position)`
  - `ping_requested(world_position)`

---

## 4. HUD / Minimap 数据契约（关键要求）

## 4.1 `update_hud(snapshot)` 契约

由 `game_manager._build_hud_snapshot()` 组装。核心字段：

- 资源区：`minerals`, `gas`, `supply_used`, `supply_cap`, `top_legacy_text`
- 模式：`mode`（none/single/multi）
- 选择信息：`selection_hint`, `selection_total`
- 单选区：
  - `single_title`, `single_detail`, `single_armor`
  - `status_health`, `status_shield`, `status_energy`
- 生产区：
  - `show_production`, `production_mode`
  - `queue_size`, `queue_progress`, `queue_preview`
  - `construction_title`, `construction_state_text`, `construction_progress`
  - `construction_icon_path`, `construction_glyph`
- 多选区：
  - `multi_roles`, `multi_role_kinds`, `multi_role_health_ratios`
  - `matrix_page_index`, `matrix_page_count`
  - `active_subgroup_kind`, `subgroup_text`
- 指令区：
  - `command_hint`
  - `command_entries`（命令卡数组）
- 其它：
  - `control_group_entries`
  - `portrait_glyph`, `portrait_title`, `portrait_subtitle`
  - `notifications`

## 4.2 `command_entries[]` 单项契约

最小可用字段：

- `id`（必须，命令回调主键）
- `label`（建议）
- `enabled`（默认 true）

可选增强字段：

- `hotkey`, `icon_path`, `cost_text`, `detail_text`
- `cooldown_ratio`（0-1）
- `disabled_reason`

## 4.3 `update_minimap(snapshot)` 契约

由 `game_manager._build_minimap_snapshot()` 组装：

- `map_half_size: Vector2`
- `player_team_id: int`
- `camera_position: Vector3`
- `camera_half_extent: Vector2`
- `units: Array[Dictionary{x,z,team,selected}]`
- `buildings: Array[Dictionary{x,z,team,selected}]`
- `resources: Array[Dictionary{x,z}]`
- `pings: Array[Dictionary{x,z,progress,kind}]`

---

## 5. 从实现反推的“必须满足”要求

## 5.1 节点路径与结构要求（强约束）

`rts_hud.gd` 使用大量 `@onready $Path`，以下必须保持稳定：

- `TopBar/...` 全链路
- `BottomHUD/BottomRow/...` 全链路
- `NotificationPanel/NotificationList`
- `SelectionPanel` 内 `MinimapPanel/MiniMapView`
- `QueueColumn` 内 `ControlGroupBar`、`SingleContainer`、`MultiMatrixRoot`
- `CommandColumn` 内 `CommandHoverPanel`、`CommandPanel/CommandGrid`

一旦改名/改层级，脚本会直接失效。

## 5.2 容量与分页要求

- 命令槽：`COMMAND_SLOTS = 20`
- 多选槽：`MULTI_SLOTS = 30`
- 队列槽：`QUEUE_SLOTS = 5`
- 多选分页上限按 `HUD_MULTI_MAX = 30`（由 `game_manager` 控制）

`game_manager` 与 `rts_hud` 的分页容量必须同步，否则会出现索引越界或显示错位。

## 5.3 输入穿透与拦截要求

- `SelectionOverlay` 必须 `MOUSE_FILTER_IGNORE`。
- `BottomHUD` 辅助布局节点保持透明且不拦截（脚本统一设置）。
- 真正交互面板（Selection/Queue/Portrait/Command）必须可拦截。
- 小地图必须 `MOUSE_FILTER_STOP` 才能接收导航拖拽。

## 5.4 小地图坐标与相机边界要求

- 统一使用 `map_half_size` 做边界裁剪。
- `game_manager` 对导航目标做世界边界 clamp。
- `rts_camera` 的 `map_half_size` 必须与 minimap snapshot 对齐，避免导航偏移。

## 5.5 命令禁用语义要求

禁用命令必须同时提供：

- `enabled = false`
- 对应 `disabled_reason`

否则 hover 面板无法向玩家解释禁用原因。

## 5.6 模式切换稳定性要求

- 多选进入时启用过渡保护（guard hidden + deferred reveal），避免矩阵首帧抖动。
- 文本变化后命令 hover 面板需要触发即时重排，避免闪动或遮挡。

---

## 6. 现有文档对照与适用性

- `docs/RTS_HUD_Manual_Layout_PRD.md`：与当前实现高度一致（手动布局主线文档，适用）。
- `docs/RTS_Interaction_PRD_AI_Progress.md`：包含大量 UI/交互迭代记录，可用于追溯。
- `docs/RTS_UI_Layout_Analysis.md`：内容是 Unity 项目路径（`Assets/...`），**不属于当前 Godot 实现基线**，不建议作为当前 UI 规范依据。

---

## 7. 建议作为后续开发“验收清单”的最小集

1. `update_hud` / `update_minimap` 字段不减不乱名。  
2. `RTSHud` 关键节点路径不改，或改动后同步脚本。  
3. 命令卡禁用项必须附禁用原因。  
4. 多选分页与 `HUD_MULTI_MAX` 保持一致。  
5. 小地图导航与相机边界 clamp 一致。  
6. 窗口 resize 后 HUD 四区块无重叠、无抖动。  
7. 透明辅助层不拦截框选。  

