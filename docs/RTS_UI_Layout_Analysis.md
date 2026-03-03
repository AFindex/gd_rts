# RTS 项目 UI 特点梳理（布局重点）

## 1. 分析范围
本梳理基于当前项目中实际生效的战斗场景与 UI 代码：

- 场景：`Assets/Scenes/BattleScene.unity`（已在 `ProjectSettings/EditorBuildSettings.asset` 中启用）
- UI 构建入口：`Assets/Editor/RtsSceneInitializer.cs`
- HUD/面板逻辑：`Assets/Scripts/UI/RtsHudController.cs`
- 指令卡：`Assets/Scripts/UI/CommandCardController.cs`、`Assets/Scripts/UI/CommandCardButtonView.cs`
- 小地图：`Assets/Scripts/UI/MinimapController.cs`
- 头像：`Assets/Scripts/UI/RtsPortraitController.cs`
- 拖拽框覆盖层：`Assets/Scripts/Input/SelectionBoxOverlay.cs`

## 2. 总体布局骨架

### 2.1 单 Canvas + 双层主带
项目采用单个 `RTS_Canvas`，核心为“上方信息带 + 下方操作带 + 弹层覆盖”的 RTS 标准结构：

- `Canvas` 模式：`ScreenSpaceOverlay`
- `CanvasScaler`：`ScaleWithScreenSize`
- 参考分辨率：`1920x1080`
- `matchWidthOrHeight = 0.5`（宽高折中缩放）

可视结构可概括为：

```text
┌──────────────────────────────────────────────────────────────────────┐
│ 游戏主视野                                                         │
│                                                      ┌────────────┐  │
│                                                      │ TopBar     │  │
│                                                      │(760x84)    │  │
│                                                      └────────────┘  │
│  NotificationPanel(左侧竖列)                                         │
│                                                                      │
│ ┌──────────────────────────────── BottomHUD(高360) ─────────────────┐ │
│ │ Selection(22%) │ Queue(40%) │ Portrait(8%) │ Command(30%)       │ │
│ └────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

### 2.2 布局策略特征
- 顶部条采用“固定像素尺寸 + 屏幕右上锚定”，不是全宽横条。
- 底部 HUD 采用“固定高度 360 + 宽度拉伸到全屏”，保证操作区稳定。
- 主要子面板以百分比锚点切分，不依赖硬编码绝对坐标。
- 关键弹层（系统菜单）采用全屏遮罩 + 中央固定窗口。

## 3. 分区布局细节

### 3.1 顶部信息区（TopBar）
`TopBar` 位于右上角：`sizeDelta = (760, 84)`，`anchoredPosition = (-12, -12)`，分三段：

- `ResourcePanel`：`0%~74%` 宽度
  - 上半区横向排布 3 组资源（矿/气/人口），每组“标签+数值”成对出现。
  - 下半区保留一行 legacy 聚合文本（兼容旧显示逻辑）。
- `CenterTop`：`74%~86%`
  - 主显示计时 `TimeText`，任务文本 `MissionText` 已预留（默认隐藏）。
- `SystemPanel`：`86%~100%`
  - 当前只启用 `MenuButton`（F10），`MapToggleButton` 与 `HelpButton` 预留但默认隐藏。

布局特点：顶部信息高度紧凑、偏“状态读数”，不抢占主视野横向空间。

### 3.2 底部操作带（BottomHUD）
`BottomHUD`：全宽、固定高 `360`。内部是四段式操作布局。

#### 3.2.1 左侧 SelectionPanel（0%~22%）
- 锚点：`(0,0) -> (0.22,1.2)`，高度拉到父容器 120%，形成“向上凸起”的操作岛。
- 内部三段：
  - 顶部 `GlobalButtonRow`：空闲工人 / 全军(F2) / 折跃门 三按钮横排。
  - 中部 `MinimapPanel`：带内边距的 RawImage 小地图，覆盖 `MarkerRoot` 与 `ViewportFrame`。
  - 底部双按钮：`PingButton` 与 `TerrainToggleButton` 近似 1:1 平分。

布局特点：把“全局战术入口（小地图+全局快捷）”集中在左手区。

#### 3.2.2 中部 QueuePanel（22%~62%，高 90%）
这是状态最复杂、切换最多的面板，采用“容器复用 + 状态显隐”而非多窗口切换：

- 入口文本：`SelectionHintText`
- 单选状态区：
  - `SingleStatusRoot`（左块）：主线框 + 生命/护盾/能量条
  - `SingleDetailRoot`（右块）：名称、详细属性、护甲类型
- 生产监控区：`ProductionQueueRoot`
  - 队列摘要、槽位计数、进度条、队列槽按钮
  - 槽位布局为“头槽宽按钮 + 后续窄槽”
- 多选矩阵区：`MultiMatrixRoot`
  - 线框网格 + 翻页按钮 + 页码
  - 网格最终为 `8` 列、`70x70` 单元，按 `24` 个/页组织

布局特点：同一块空间承载单选详情、建筑生产、多选矩阵三种视图，信息密度高且切换成本低。

#### 3.2.3 PortraitPanel（62%~70%）
- 独立 3D 头像列，宽度约 8%。
- 上标题、中间渲染图、下名称三段式。
- 与中部状态面板和右侧指令卡之间形成视觉缓冲带。

布局特点：在不增大主要操作成本的前提下，补充单位识别反馈。

#### 3.2.4 CommandPanel（70%~100%）
- 右侧 30% 宽，主用于指令卡。
- `CommandGrid` 占面板下部约 86%，使用 `GridLayoutGroup`：
  - 固定 `5` 列
  - `cellSize = 100x100`
  - `spacing = 8x8`
  - 结合 `maxButtons = 15`，形成典型 `5x3` 战术按钮矩阵
- 顶部保留 `SubgroupText`（子编队提示），并可动态显示 hover 提示条。

布局特点：遵循 RTS 右下角“动作面板”习惯，空间稳定，肌肉记忆友好。

### 3.3 弹层与辅助区

#### 3.3.1 系统菜单弹层
- `SystemMenuOverlay` 全屏半透明遮罩（默认隐藏）。
- `SystemMenuPanel` 居中固定 `820x520`。
- 打开菜单时会关闭镜头边缘滚屏，关闭后恢复。

#### 3.3.2 通知列
- 左侧固定宽约 `340` 的纵向区域。
- 文本条目从左滑入、停留、再左滑出（并带透明度过渡）。

#### 3.3.3 拖拽框覆盖层
- `SelectionBoxOverlay` 使用 `OnGUI` 绘制半透明填充 + 高亮边框。
- 作为屏幕态覆盖，不占 HUD 固定面板空间。

## 4. 布局的“状态机”特征（核心）
`RtsHudController.RefreshSelectionPanel` 决定中部布局切换逻辑：

- 无选择：
  - 隐藏单选/生产/矩阵区，清空队列显示，头像回到未锁定状态。
- 单选（普通单位/建筑非生产态）：
  - 显示 `SingleStatusRoot + SingleDetailRoot`。
- 单选（建筑建造/训练/队列进行中）：
  - 显示 `SingleStatusRoot + ProductionQueueRoot`，突出产线信息。
- 多选：
  - 显示 `MultiMatrixRoot`，用线框矩阵呈现编队健康与构成。

这意味着该 UI 不是固定面板堆叠，而是“同区域复用 + 语义态切换”，是本项目布局最关键的设计点。

## 5. 视觉层级与风格特征
- 主色调：深蓝/青蓝半透明面板，符合科幻 RTS 语义。
- 层级对比：
  - 背板偏暗，文本与高亮偏亮（青/白/红/黄）
  - 资源涨跌、人口告警、队列暂停等用颜色直接编码状态
- 按钮视觉：
  - 指令按钮由 Outline/Background/Icon/Hotkey/Cooldown/Lock 多层叠加
  - 锁定态、冷却态、不可用态均有独立视觉反馈

## 6. 交互与布局协同点
- `F10` 打开菜单与弹层布局联动（冻结边缘滚屏，避免误操作）。
- 小地图支持：点击跳转、Alt 发送信号、独立“信号模式”、地形配色切换。
- 指令卡支持：Tab 子群切换、热键自动分配、hover 说明、资源/前置条件锁定态。
- 头像区支持点击回镜头中心，连接“信息展示区”与“相机控制”。

## 7. 结论（布局维度）
这个 RTS 项目的 UI 布局特征可以总结为：

1. 底部四分区稳定骨架（选择/状态/头像/指令）+ 顶部紧凑信息条。
2. 中央状态区采用“单选-生产-多选矩阵”的复用式状态布局，是信息密度与可读性平衡点。
3. 左侧小地图与全局按钮聚合，右侧命令卡固定 5x3 网格，形成典型 RTS 双手分工。
4. 锚点百分比与固定高度/宽度混合，确保常见分辨率下布局形态稳定且可预测。
