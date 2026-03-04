# RTS HUD 手动布局改造 PRD

版本：v1.0  
日期：2026-03-04  
状态：实施中（P2）

---

## 1. 背景与问题

当前 HUD 大量依赖 `HBoxContainer / VBoxContainer / GridContainer` 自动布局。  
在 RTS 高频交互场景下，自动回流会带来以下问题：

- 分页与多选矩阵在内容刷新时发生布局抖动。
- 透明占位控件容易出现意外拦截输入。
- 命令面板/悬浮信息面板位置受容器行为影响，不易精确对齐。
- 后续做 SC2 风格精细排版（像素级）困难。

---

## 2. 目标与非目标

### 2.1 目标

- 用脚本统一计算 HUD 关键区域布局，降低容器自动回流影响。
- 建立可配置的手动布局参数（间距、比例、内边距）。
- 保持现有交互逻辑不变（命令触发、分页、编组、悬浮说明）。

### 2.2 非目标

- 本阶段不改动美术风格与主题。
- 本阶段不重构 `game_manager` 交互协议。
- 本阶段不一次性替换所有内层容器，只先替换外层骨架。

---

## 3. 范围定义

### 3.1 本阶段（P0/P1）范围

- `TopBar/TopBarRow` 由自动容器改为手动布局根节点。
- `BottomHUD/BottomRow` 由自动容器改为手动布局根节点。
- 四大区块由脚本手动计算：
  - `SelectionPanel`
  - `QueueColumn`
  - `PortraitColumn`
  - `CommandColumn`
- 顶部三分区由脚本手动计算：
  - `ResourcePanel`
  - `CenterTop`
  - `SystemPanel`
- 响应窗口尺寸变化时自动重排（`NOTIFICATION_RESIZED`）。

### 3.2 后续阶段范围

- `QueueColumn` 内部子模块手动化（编组条/单体信息/多选矩阵）。
- `CommandGrid`、`MatrixGrid` 网格手动化。
- 顶部资源条与通知区手动化（可选）。

---

## 4. 技术设计

### 4.1 核心思路

- 在 `rts_hud.gd` 增加统一入口：`_apply_manual_bottom_layout()`。
- 在 `_ready()` 和窗口尺寸变化时调用 `reflow`。
- 通过 `manual_bottom_section_ratios` 控制四大区宽度占比。

### 4.2 布局参数

- `use_manual_bottom_layout`：是否启用底部手动布局。
- `manual_bottom_gap`：四区块横向间距。
- `manual_bottom_padding`：底部区域内边距（x/y）。
- `manual_bottom_section_ratios`：四区块宽度比例（Selection/Queue/Portrait/Command）。

### 4.3 计算规则

- 可用宽度：`usable_width = total_width - padding_x*2 - gap*(section_count-1)`
- 可用高度：`usable_height = total_height - padding_y*2`
- 分区宽度：按比例分配，最后一区吸收浮点误差。
- 每个分区设置 `position + size`，不依赖容器自动排布。

---

## 5. 里程碑计划

## P0：基线冻结（已完成）

- 新建本 PRD 文档，明确分阶段改造策略。
- 明确“先外层、后内层”的低风险路径。

## P1：外层骨架手动化（进行中）

- 将 `TopBarRow` 改为 `Control`，顶部三段改为手动 `reflow`。
- 将 `BottomRow` 改为 `Control`。
- 实现四大区块手动 `reflow`。
- 保持内部逻辑和 UI 功能行为不变。

验收标准：

- 窗口尺寸变化时，四大区块位置稳定、无重叠。
- 现有命令交互、编组、分页、悬浮说明无回归。

## P2：Queue 子布局手动化（进行中）

- 编组条、单体信息块、多选矩阵的几何位置全部脚本计算。

当前进展（2026-03-04）：

- 已提前完成 P2 的“列级壳层”手动化：`QueueColumn / PortraitColumn / CommandColumn` 改为 `Control`，并由脚本分别计算列内主分区（Queue 顶部+内容、Portrait 顶部+内容、Command Hover+Panel）。
- `QueuePanel` 已完成第一层内容手动化：`QueueContent` 改为 `Control`，由脚本计算 `SelectionHintText` 与内容主区。
- `SingleContainer` 已完成壳层手动化：改为 `Control` 并由脚本计算 `SingleStatusRoot` 与右侧 `SingleDetailRoot/ProductionQueueRoot` 分栏。
- `MultiMatrixRoot` 已完成壳层手动化：`MultiMatrixContent/MatrixBody` 改为 `Control` 并由脚本计算 `MatrixFooter` 与 `MatrixGrid` 分栏。
- `SingleStatusContent / SingleDetailContent / ProductionContent` 已改为 `Control` 并接入手动布局，分别计算状态条纵向结构、详情区纵向结构、生产队列纵向结构。
- `CommandPanel` 已完成第一层内容手动化：`CommandContent` 改为 `Control`，由脚本计算 `SubgroupText` / `CommandGrid` / `CommandHintText` 三段布局。
- `CommandGrid` 已改为 `Control` 并接入手动格子定位（5列参数化、间距参数化），命令卡不再依赖 `GridContainer` 自动回流。

## P3：网格手动化（进行中）

- `CommandGrid` 与 `MatrixGrid` 改为纯脚本网格定位。

当前进展（2026-03-04）：

- `CommandGrid` 已切换为 `Control` 并完成手动格子排版（列数/间距/尺寸参数化）。
- `MatrixGrid` 已切换为 `Control` 并完成手动格子排版（列数/间距/尺寸参数化）。
- `MatrixFooter / MatrixPageButtons` 已切换为 `Control` 并完成分页按钮手动纵向布局（按钮高度/间距/宽度参数化）。

## P4：跨分辨率收尾（待开始）

- 回归测试：`1280x720 / 1600x900 / 1920x1080 / 2560x1440 / 3440x1440`。

---

## 6. 风险与对策

- 风险：切换节点类型后，旧 `size_flags` 语义失效。  
  对策：先只改一层骨架，内部容器维持现状，逐层替换。

- 风险：窗口变化触发过于频繁导致抖动。  
  对策：使用 `_manual_layout_refresh_pending + call_deferred` 合并重排请求。

- 风险：透明辅助层再次拦截框选。  
  对策：保持 `mouse_filter` 策略不变，并加入回归清单。

---

## 7. 验收与测试清单

1. 启动后 HUD 四大区块按预期比例显示。  
2. 拖动窗口尺寸，四区块稳定重排。  
3. 命令卡 hover 固定面板仍正常更新。  
4. 多选分页按钮和编组按钮仍可点击。  
5. 透明区域拖拽框选不被拦截。  
6. 运行 `godot --headless --path d:\\Godot\\projs\\gd_rts --quit --verbose` 无解析错误。

---

## 8. 进度记录

- 2026-03-04：
  - 新建文档。
  - 启动 P1：顶部/底部外层手动布局实现中。
- 2026-03-05：
  - 完成 TopBar 全宽锚定修正（去除固定壳宽约束），并对 NotificationPanel 增加裁剪与高度收敛，降低文本越界覆盖风险。
  - 单体区分栏加入最小宽度约束与比例修正，缓解 `SingleStatus/Detail` 在窄宽度条件下错位。
  - 修复手动布局刷新稳定性：增加布局重入保护并收敛 deferred 刷新策略，`godot --headless --path d:\\Godot\\projs\\gd_rts --quit --verbose` 已通过（无崩溃）。
  - 增加手动布局 warmup 重排（前3帧强制刷新），修复首帧尺寸未就绪时 `QueueContent/CommandGrid` 的 0 高度/异常高度问题。
  - 底部四区比例改为 `18/40/10/32`，并下调命令/矩阵网格间距，提升默认分辨率下命令卡有效尺寸。
  - 命令格/矩阵格改为按可用空间填充布局，并在 [skill_command_item.tscn](D:/Godot/projs/gd_rts/scenes/ui/skill_command_item.tscn) 取消命令项默认最小尺寸约束；同时清除运行时 `custom_minimum_size` 约束，避免小窗口下重叠和错位。
