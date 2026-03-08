# RTS 测试配置梳理与重构（2026-03）

## 1. 现有测试配置（改造前）
- 单位：核心可训练单位仅 `worker`、`soldier` 两类。
- 建筑：`base` + 多个测试建筑（`barracks / tower / academy / engineering_bay / tech_lab / warp_gate / psionic_relay / bio_vat / void_core`）。
- 科研：仅有 4 条（`infantry_weapons_1 / infantry_armor_1 / field_logistics / advanced_targeting`）。
- 资源：运行时经济只结算矿物（Minerals），HUD 虽有 Gas 字段但固定显示 0。

## 2. 重构目标
- 建立“主基地 -> 中期分支 -> 高阶融合”的建筑层级。
- 让单位形成“经济/步兵/重装/机甲/特战”多定位分层。
- 将资源系统扩展为 `Minerals + Gas` 双资源，并接入采集与消耗。

## 3. 新建筑树（测试配置）
- T0 起点：
  - `base`（主基地，工人生产与建造入口）
  - `supply_depot`（人口/后勤）
- T1 军事基础：
  - `barracks`（基础步兵线）
  - `tower`（防御塔，依赖 `supply_depot`）
  - `academy`（步兵与后勤科研）
- T2 分支扩展：
  - `engineering_bay`（机械与重装科研）
  - `psionic_relay`（支援科研，依赖 `field_logistics`）
- T3 生产分支：
  - `bio_vat`（重装生化兵线）
  - `warp_gate`（机甲兵线，依赖 `mech_chassis`）
  - `tech_lab`（高级步兵/精确制导科研）
- T4 终局：
  - `void_core`（终局单位与量子指挥科研）

## 4. 新单位分层（每类含变体）
- 经济工程：
  - `worker`（Engineer）
  - `field_technician`
  - `hauler_drone`
- 前线步兵：
  - `soldier`（Rifleman）
  - `assault_trooper`
  - `marksman`
- 重装压制：
  - `heavy_gunner`
  - `rocket_trooper`
- 机甲机动：
  - `scout_mech`
  - `siege_mech`
- 特战终局：
  - `commando`

## 5. 新科技树（核心路线）
- 步兵线：`infantry_weapons_1 -> infantry_weapons_2`
- 防护线：`infantry_armor_1 -> infantry_armor_2 -> heavy_plating`
- 后勤线：`field_logistics -> support_protocols`
- 机械线：`field_logistics -> mech_chassis`
- 终局线：`precision_targeting + heavy_plating -> quantum_command`

## 6. 双资源规则
- 资源类型：
  - `minerals`
  - `gas`
- 采集：
  - 同一 `resource_node` 脚本支持矿点与瓦斯点（`resource_type` 区分）。
  - 工人会携带资源类型信息，回收时按类型入账至对应队伍资源池。
- 消耗：
  - 单位训练和科技研究改为支持矿/气联合扣费。
  - HUD 资源栏显示实时 `MIN / GAS`。
