# Phase-4 设计说明（基础体系收口）

## 1. 阶段定位

Phase-4 不是新增分支，而是把前三期未纳入分期的“基础与过渡条目”统一收口，形成完整的内容闭环。

本阶段条目来自“剩余池”自动计算：
- 建筑：`7`
- 单位：`10`
- 科技：`6`
- 技能：`24`

为什么不是 `5/8/10/20`：
- 经过 Phase-1 ~ Phase-3 后，未覆盖科技只剩 `6` 条。
- 为保持跨期无重复，Phase-4 采用“剩余全收口”策略，确保全量覆盖。

## 2. 收口内容价值

### 2.1 建筑（基础主干）

`base / supply_depot / barracks / tower / academy / engineering_bay / tech_lab`

价值：
- 这些建筑是全科技树和生产树的主干节点。
- 将其放入收口期，方便做“新手引导版内容包”和“AI 基线策略包”。

### 2.2 单位（基础主力）

`worker / field_technician / hauler_drone / soldier / assault_trooper / marksman / heavy_gunner / rocket_trooper / scout_mech / repair_mech`

价值：
- 覆盖经济、步兵、重装三类最常驻编队。
- 这批单位是 PVE/PVP 基线平衡的首要对象，便于先做稳定版本。

### 2.3 科技（主干前置）

`infantry_weapons_1 / infantry_weapons_2 / infantry_armor_1 / infantry_armor_2 / field_logistics / support_protocols`

价值：
- 全部属于“主干分支前置”。
- 若主干前置不纳入统一期，后续接入会出现跨期依赖分散的问题。

### 2.4 技能（通用与基线）

包含四类：
- 通用指令：`move/attack/gather/repair/return_resource/stop`
- 基础训练：工兵、步兵、基础重装训练技能
- 主干科研：机械前置与支援前置研究入口
- 基础战术主动：`stim_pack/focus_shot/grenade_barrage`

价值：
- 这批技能是“可玩底盘”，也是 UI 技能栏和 AI 指令系统的最低覆盖集。

## 3. 与前三期的关系

Phase-1：中期开枝与第一批战术件  
Phase-2：中后期支援重装协同  
Phase-3：终局会师与胜负手  
Phase-4：基础体系与主干前置收口

这样四期组合后，形成：
- 从基础到终局的完整树形覆盖
- 没有跨期重复 ID
- 每期都有可单独评审、单独接入、单独回滚的边界

## 4. 接入建议（最小风险）

1. 先把 Phase-4 作为“默认可见包”，Phase-1~3 作为“扩展包”。  
2. 在 HUD 增加 `phase_tag` 或 `status_tag` 过滤（先只读 CSV 字段，不改战斗逻辑）。  
3. AI 先接入 Phase-4 的稳定生产与研究循环，后续再逐期解锁高阶分支。  
4. 主动技能按“视觉占位 -> 实际效果 -> 平衡调参”三步走。  

## 5. 验收标准

数据完整性：
- Phase-4 CSV 条数固定为 `7/10/6/24`
- 四期合并后分别等于主占位总量：`22/34/36/84`

设计完整性：
- 基础主干、分支扩展、终局会师三层均有明确条目
- 每类条目（建筑/单位/科技/技能）都能映射到清晰的阶段目标
