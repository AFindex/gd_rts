# RTS 扩容设计草图与占位蓝图（2026-03-09）

## 1. 目标与范围

本蓝图面向当前 `gd_rts` 的下一阶段内容扩容，目标是先完成“设计定版 + 占位落盘”，尽量不改运行时代码。

本次交付聚焦：
- 明确扩容目标规模：建筑 `22`、单位 `34`、科技 `36`、技能 `84`（含现有与新增）。
- 建立可扩展的层级结构：经济/战斗/科技/终局四层推进。
- 输出结构化占位文件（CSV），作为后续批量生成 `.tres` 的来源。
- 不直接接入 `scripts/core/config/rts_config_registry.gd` 的运行时目录，避免影响现有可玩版本。

本次不做：
- 不重构战斗系统代码。
- 不强行把新增内容接入 UI 或 AI 逻辑。
- 不在本轮调参到平衡可玩。

---

## 2. 扩容总览

### 2.1 目标规模

| 模块 | 当前 | 目标 | 本次动作 |
|---|---:|---:|---|
| 建筑 | 11 | 22 | 产出完整清单 + 占位 |
| 单位 | 11 | 34 | 产出完整清单 + 占位 |
| 科技 | 10 | 36 | 产出完整清单 + 占位 |
| 技能 | 51 | 84 | 产出完整清单 + 占位 |

### 2.2 设计原则

1. 先保证“分工差异”再堆数量，避免同质化扩容。  
2. 每条分支至少有 `生产入口 + 对应科技 + 战术技能` 三件套。  
3. 终局内容由“多分支会师”解锁，不允许单线直冲。  
4. 扩容条目全部给出 `id` 与前置关系，后续可自动生成资源。  

---

## 3. 建筑蓝图（22）

### 3.1 建筑分层

- T0 基础：`base`、`supply_depot`、`refinery`
- T1 军事基础：`barracks`、`tower`、`academy`、`forward_outpost`
- T2 分支展开：`engineering_bay`、`psionic_relay`、`armory`、`sensor_spire`、`med_bay`
- T3 生产与战术：`bio_vat`、`warp_gate`、`tech_lab`、`drone_bay`、`shield_array`、`artillery_foundry`
- T4 终局会师：`void_core`、`air_control_hub`、`command_uplink`、`orbital_array`

### 3.2 建筑清单（含占位）

| id | 显示名 | 层级 | 类型 | 施工范式 | 关键前置 | 主要产出 |
|---|---|---|---|---|---|---|
| base | Command Base | T0 | 枢纽 | summoning | 无 | 工程单位、建造入口 |
| supply_depot | Logistics Depot | T0 | 经济 | garrisoned | base | 供给上限 |
| refinery | Field Refinery | T0 | 经济 | garrisoned | base | 气体采集效率相关 |
| barracks | Barracks | T1 | 生产 | garrisoned | base | 基础步兵 |
| tower | Defense Tower | T1 | 防御 | garrisoned | base+supply_depot | 区域防守 |
| academy | Tactics Academy | T1 | 科研 | garrisoned | base+barracks | 步兵/后勤科技 |
| forward_outpost | Forward Outpost | T1 | 功能 | summoning | base+barracks | 前线补给/集结 |
| engineering_bay | Engineering Bay | T2 | 科研 | garrisoned | base+academy+supply_depot | 机械/重装科技 |
| psionic_relay | Support Relay | T2 | 科研 | summoning | base+academy+field_logistics | 支援科技 |
| armory | Armory | T2 | 科研 | garrisoned | base+engineering_bay | 重武器线 |
| sensor_spire | Sensor Spire | T2 | 功能 | summoning | base+academy | 侦测/反隐 |
| med_bay | Med Bay | T2 | 功能 | garrisoned | base+academy | 医疗/恢复强化 |
| bio_vat | Bio Vat | T3 | 生产 | incorporated | base+engineering_bay+psionic_relay | 重装生化单位 |
| warp_gate | Warp Gate | T3 | 生产 | summoning | base+engineering_bay+mech_chassis | 机甲单位 |
| tech_lab | Tech Lab | T3 | 科研 | incorporated | base+engineering_bay+field_logistics | 高阶科研 |
| drone_bay | Drone Bay | T3 | 生产 | summoning | base+refinery+support_protocols | 无人机线 |
| shield_array | Shield Array | T3 | 功能 | incorporated | base+tech_lab+infantry_armor_2 | 护盾网络 |
| artillery_foundry | Artillery Foundry | T3 | 生产 | garrisoned | base+armory+precision_targeting | 远程重火力 |
| void_core | Void Core | T4 | 终局 | incorporated | base+tech_lab+warp_gate+bio_vat | 终局单位/科技 |
| air_control_hub | Air Control Hub | T4 | 生产 | summoning | base+drone_bay+mech_chassis | 空优/无人机进阶 |
| command_uplink | Command Uplink | T4 | 科研 | incorporated | base+void_core+support_protocols | 指挥链科技 |
| orbital_array | Orbital Array | T4 | 终局 | summoning | base+command_uplink+quantum_command | 轨道技能 |

---

## 4. 单位蓝图（34）

### 4.1 职能分组

- 经济工程（8）：采集、运输、维修、前线施工。
- 步兵战线（12）：近战突击、中程火力、反隐渗透、阵地压制。
- 重装机甲（10）：坦压、反甲、远程炮击、机动支援。
- 特战指挥（4）：终局英雄化单位与全局战术单位。

### 4.2 单位清单（含占位）

| id | 显示名 | 层级 | 分组 | 生产建筑 | 定位 | 代表技能占位 |
|---|---|---|---|---|---|---|
| worker | Engineer | T0 | 经济工程 | base | 基础采修建 | build_menu |
| field_technician | Field Technician | T1 | 经济工程 | base | 高速维修 | repair_field |
| hauler_drone | Hauler Drone | T1 | 经济工程 | base | 运输专精 | rapid_return |
| salvage_truck | Salvage Truck | T2 | 经济工程 | forward_outpost | 前线回收 | salvage_beam |
| gas_siphon_drone | Gas Siphon Drone | T2 | 经济工程 | refinery | 专精采气 | gas_overdrive |
| combat_medic | Combat Medic | T2 | 经济工程 | med_bay | 战地治疗 | triage_pulse |
| logistics_officer | Logistics Officer | T3 | 经济工程 | command_uplink | 后勤增益 | supply_surge |
| fabrication_drone | Fabrication Drone | T3 | 经济工程 | drone_bay | 快速施工 | instant_fabricate |
| soldier | Rifleman | T1 | 步兵战线 | barracks | 基础火力 | attack |
| assault_trooper | Assault Trooper | T2 | 步兵战线 | barracks | 近距突入 | stim_pack |
| marksman | Marksman | T2 | 步兵战线 | barracks | 远程点杀 | focus_shot |
| breacher | Breacher | T2 | 步兵战线 | barracks | 破阵开路 | breach_charge |
| grenadier | Grenadier | T2 | 步兵战线 | barracks | 群体压制 | grenade_barrage |
| flamelancer | Flame Lancer | T2 | 步兵战线 | bio_vat | 近域清场 | flame_wave |
| suppressor | Suppressor | T3 | 步兵战线 | armory | 持续压制 | suppressive_fire |
| recon_sniper | Recon Sniper | T3 | 步兵战线 | sensor_spire | 侦查狙击 | mark_target |
| shieldbearer | Shield Bearer | T3 | 步兵战线 | shield_array | 阵地承伤 | fortify_mode |
| infiltrator | Infiltrator | T3 | 步兵战线 | psionic_relay | 渗透反后排 | cloak_step |
| vanguard | Vanguard | T4 | 步兵战线 | command_uplink | 高生存前排 | guardian_field |
| guardian | Guardian | T4 | 步兵战线 | command_uplink | 指挥光环 | command_aura |
| heavy_gunner | Heavy Gunner | T3 | 重装机甲 | bio_vat | 中程重火力 | overdrive |
| rocket_trooper | Rocket Trooper | T3 | 重装机甲 | bio_vat | 反甲输出 | lock_on_missile |
| scout_mech | Scout Mech | T3 | 重装机甲 | warp_gate | 高机动侦察 | boost_dash |
| siege_mech | Siege Mech | T4 | 重装机甲 | warp_gate | 长程攻坚 | siege_mode |
| assault_mech | Assault Mech | T3 | 重装机甲 | warp_gate | 机甲前排 | impact_charge |
| aa_mech | AA Mech | T3 | 重装机甲 | air_control_hub | 防空压制 | flak_burst |
| support_mech | Support Mech | T3 | 重装机甲 | warp_gate | 机甲支援 | repair_field |
| artillery_mech | Artillery Mech | T4 | 重装机甲 | artillery_foundry | 超远程炮击 | artillery_barrage |
| guardian_tank | Guardian Tank | T4 | 重装机甲 | armory | 重装推进 | bunker_mode |
| disruptor_walker | Disruptor Walker | T4 | 重装机甲 | void_core | 高科技压制 | disruptor_blast |
| repair_mech | Repair Mech | T4 | 重装机甲 | drone_bay | 机械维修 | repair_swarm |
| commando | Command Operative | T4 | 特战指挥 | void_core | 终局特战 | phase_shift |
| psionic_adept | Psionic Adept | T4 | 特战指挥 | psionic_relay | 控场干扰 | psionic_storm |
| warlord | Warlord | T4 | 特战指挥 | command_uplink | 终局统御 | rally_cry |

---

## 5. 科技蓝图（36）

### 5.1 主分支

- 步兵武器线：`infantry_weapons_1 -> infantry_weapons_2 -> infantry_weapons_3`
- 步兵护甲线：`infantry_armor_1 -> infantry_armor_2 -> infantry_armor_3`
- 机械底盘线：`field_logistics -> mech_chassis -> servo_actuators`
- 机械火力线：`mech_weapons_1 -> mech_weapons_2 -> mech_weapons_3`
- 机械防护线：`mech_plating_1 -> mech_plating_2 -> mech_plating_3`
- 支援后勤线：`field_logistics -> support_protocols -> logistics_network`
- 终局指挥线：`precision_targeting + heavy_plating -> quantum_command -> command_matrix -> phase_manipulation`

### 5.2 科技清单（含占位）

| id | 分支 | 层级 | 研究建筑 | 关键前置 | 主要效果占位 |
|---|---|---|---|---|---|
| infantry_weapons_1 | infantry | T1 | academy | 无 | 步兵攻击+ |
| infantry_weapons_2 | infantry | T2 | tech_lab | infantry_weapons_1 | 步兵攻击++ |
| infantry_weapons_3 | infantry | T3 | tech_lab | infantry_weapons_2 | 步兵攻击+++ |
| infantry_armor_1 | infantry | T1 | academy | 无 | 步兵护甲+ |
| infantry_armor_2 | infantry | T2 | tech_lab | infantry_armor_1 | 步兵护甲++ |
| infantry_armor_3 | infantry | T3 | tech_lab | infantry_armor_2 | 步兵护甲+++ |
| squad_tactics | infantry | T2 | academy | infantry_weapons_1 | 编队增益 |
| stim_injection | infantry | T2 | academy | squad_tactics | 冲锋技能解锁 |
| adaptive_camouflage | infantry | T3 | sensor_spire | squad_tactics | 潜行相关 |
| composite_ballistics | infantry | T3 | armory | infantry_weapons_2 | 穿甲增益 |
| field_logistics | logistics | T1 | academy | 无 | 后勤分支开启 |
| support_protocols | logistics | T2 | psionic_relay | field_logistics | 支援分支开启 |
| logistics_network | logistics | T3 | command_uplink | support_protocols | 补给效率 |
| auto_refining | logistics | T2 | refinery | field_logistics | 采气效率 |
| combat_medicine | logistics | T2 | med_bay | field_logistics | 治疗效率 |
| emergency_repair | logistics | T3 | med_bay | combat_medicine | 战地快修 |
| heavy_plating | heavy | T2 | engineering_bay | infantry_armor_1 | 重装生化解锁 |
| mech_chassis | heavy | T2 | engineering_bay | field_logistics | 机甲线开启 |
| mech_weapons_1 | heavy | T2 | engineering_bay | mech_chassis | 机甲攻击+ |
| mech_weapons_2 | heavy | T3 | tech_lab | mech_weapons_1 | 机甲攻击++ |
| mech_weapons_3 | heavy | T4 | command_uplink | mech_weapons_2 | 机甲攻击+++ |
| mech_plating_1 | heavy | T2 | engineering_bay | mech_chassis | 机甲护甲+ |
| mech_plating_2 | heavy | T3 | tech_lab | mech_plating_1 | 机甲护甲++ |
| mech_plating_3 | heavy | T4 | command_uplink | mech_plating_2 | 机甲护甲+++ |
| servo_actuators | heavy | T3 | engineering_bay | mech_chassis | 机动性提升 |
| missile_guidance | heavy | T3 | armory | mech_weapons_1 | 导弹追踪 |
| siege_calibration | heavy | T4 | artillery_foundry | precision_targeting | 攻城强化 |
| drone_link | support | T3 | drone_bay | support_protocols | 无人机协同 |
| air_control | support | T4 | air_control_hub | drone_link | 空域控制 |
| reactive_shields | support | T3 | shield_array | infantry_armor_2 | 护盾触发 |
| structure_overclock | support | T3 | shield_array | support_protocols | 建筑性能提升 |
| precision_targeting | command | T3 | tech_lab | infantry_weapons_2+field_logistics | 精准打击 |
| quantum_command | command | T4 | void_core | precision_targeting+heavy_plating | 终局指挥 |
| command_matrix | command | T4 | command_uplink | quantum_command | 全局光环 |
| orbital_targeting | command | T4 | orbital_array | command_matrix | 轨道打击 |
| phase_manipulation | command | T4 | void_core | command_matrix+orbital_targeting | 相位技能 |

---

## 6. 技能蓝图（84）

### 6.1 技能结构（目标）

- 通用命令：10
- 建造相关：20
- 训练相关：34
- 科研相关：36
- 战术主动：20

说明：
- 总量按“最终目标”统计，含已有与新增。
- 本次占位重点落新增技能 id，避免先改行为代码。

### 6.2 新增战术主动（建议首批）

| id | 来源类型 | 来源 | target_mode | 说明 |
|---|---|---|---|---|
| stim_pack | unit | assault_trooper | none | 短时攻速与移速提升 |
| focus_shot | unit | marksman | unit_or_building | 蓄力单点 |
| breach_charge | unit | breacher | ground | 破阵冲锋 |
| grenade_barrage | unit | grenadier | ground | 抛投范围伤害 |
| suppressive_fire | unit | suppressor | unit_or_building | 压制减速 |
| cloak_step | unit | infiltrator | none | 短时隐匿 |
| mark_target | unit | recon_sniper | unit_or_building | 标记增伤 |
| fortify_mode | unit | shieldbearer | none | 原地防御姿态 |
| siege_mode | unit | siege_mech | none | 切换攻城模式 |
| artillery_barrage | unit | artillery_mech | ground | 远程弹幕 |
| overdrive | unit | heavy_gunner | none | 火力过载 |
| lock_on_missile | unit | rocket_trooper | unit_or_building | 锁定导弹 |
| repair_field | unit | support_mech | friendly_building | 范围修复 |
| disruptor_blast | unit | disruptor_walker | ground | 扰频爆裂 |
| psionic_storm | unit | psionic_adept | ground | 心灵风暴 |
| rally_cry | unit | warlord | none | 群体士气增益 |
| scan_sweep | building | sensor_spire | ground | 侦测扫描 |
| deploy_bunker | building | forward_outpost | placement | 部署临时掩体 |
| call_drop_pod | building | command_uplink | ground | 空投支援 |
| orbital_strike | building | orbital_array | ground | 轨道打击 |

---

## 7. 占位落地规则

### 7.1 占位文件位置

- `docs/content_expansion/placeholders/buildings_v2_placeholder.csv`
- `docs/content_expansion/placeholders/units_v2_placeholder.csv`
- `docs/content_expansion/placeholders/techs_v2_placeholder.csv`
- `docs/content_expansion/placeholders/skills_v2_placeholder.csv`

### 7.2 字段约定

1. `id` 统一小写下划线风格，和现有 `.tres` 风格一致。  
2. `status` 默认 `planned`，落地到可玩后改为 `implemented`。  
3. `requires_buildings` 与 `requires_tech` 统一用 `|` 分隔，便于后续脚本 split。  
4. `source_ids` 用于技能来源列表，支持一个技能多来源复用。  
5. `placeholder_*` 字段可在后续批量导出 `.tres` 时映射到 `stats/extra`。  

### 7.3 建议生成链路（下一步）

1. 用 CSV 作为单一真源（SSOT）。  
2. 写一个轻量导出脚本，把 CSV 生成为 `config/*/*.tres`。  
3. 先生成资源文件不接技能入口，做“静态完整性校验”。  
4. 分阶段接 UI/AI/科技效果逻辑。  

---

## 8. 分阶段实施建议

### 阶段 A：设计冻结（当前）

- 冻结条目 id 与分层关系。
- 完成占位表并过一次命名冲突检查。

### 阶段 B：资源接入（低代码）

- 分批把 `planned` 转为 `.tres` 资源。
- 保持“不可见但可加载”的灰度接入方式。

### 阶段 C：能力补齐（中代码）

- 科技效果从“仅解锁”扩展到“数值修正/行为开关”。
- AI 生产策略接入更多 unit_kind 与 research 行为。
- HUD 支持技能分页与分组筛选。

### 阶段 D：平衡与体验（高迭代）

- 基于对局数据调成本、人口、时间和分支强度。
- 做单位克制矩阵与战术窗口调优。

---

## 9. 风险与控制

1. 风险：数量上去但同质化。  
控制：每个新单位必须绑定“签名技能 + 明确克制标签”。

2. 风险：科技树冗长但无决策价值。  
控制：每条科技明确“数值收益 + 解锁收益 + 机会成本”。

3. 风险：AI 无法使用新增内容。  
控制：占位阶段即给 `unit_kind` 与 `building_roles` 做映射规划。

4. 风险：接入过快导致运行时回归。  
控制：先文档与占位、后分批接入、每批可回滚。

---

## 10. 本次产出结论

- 这版蓝图已经把 `20+ 建筑 / 30+ 单位 / 数十科技与技能` 落成了可执行的数据草图。  
- 你可以先按占位表做审阅与删改，不需要先动核心玩法代码。  
- 下一轮可以直接基于这些占位批量生成 `.tres`，把扩容从“想法”推进到“资产层落地”。
