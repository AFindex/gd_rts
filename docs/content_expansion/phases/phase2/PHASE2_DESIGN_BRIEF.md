# Phase-2 设计说明（支援重装分支）

## 1. 目标定位

Phase-2 的目标不是继续横向铺数量，而是把 `T3 -> T4` 的中后期决策做厚，形成“重装推进 + 支援协同”的第二个可选主流打法。

本阶段固定范围：
- 建筑：`5`
- 单位：`8`
- 科技：`10`
- 技能：`20`

和 Phase-1 的关系：
- Phase-1 解决“中期开枝”和基础战术件。
- Phase-2 解决“中后期成型”和分支差异放大。

## 2. 内容清单与功能意图

### 2.1 建筑（5）

| id | 层级 | 作用 | 设计意图 |
|---|---|---|---|
| drone_bay | T3 | 无人机与辅助机体入口 | 给经济/维修链一个战斗化转型入口 |
| shield_array | T3 | 护盾/建筑强化科技入口 | 提供“阵地运营”路线，不只拼正面输出 |
| artillery_foundry | T3 | 远程重火力生产与科研入口 | 给慢推进打法提供强攻坚手段 |
| air_control_hub | T4 | 空优/防空相关单位入口 | 解决中后期空域与反空缺口 |
| command_uplink | T4 | 指挥链科技与终局步兵入口 | 把多个分支会师到战略级能力 |

### 2.2 单位（8）

| id | 分组 | 作用 | 与其他条目协同 |
|---|---|---|---|
| fabrication_drone | economy | 快速施工/补建 | 与 `structure_overclock`、前线据点联动 |
| shieldbearer | infantry | 阵地承伤 | 与 `reactive_shields` 绑定，提升前排稳定性 |
| logistics_officer | economy | 后勤增益单位 | 与 `logistics_network` 形成运营收益 |
| assault_mech | heavy | 机甲前排突进 | 与 `servo_actuators` 提升机动切入 |
| aa_mech | heavy | 防空压制 | 与 `air_control` 构成空域控制核心 |
| support_mech | heavy | 机甲支援/维修 | 强化机械部队持续作战能力 |
| artillery_mech | heavy | 超远程攻坚 | 与 `siege_calibration` 形成核心火力点 |
| vanguard | infantry | 高生存终局前排 | 与 `command_matrix` 形成终局推进阵型 |

### 2.3 科技（10）

| id | 分支 | 角色 |
|---|---|---|
| logistics_network | logistics | 资源/补给效率放大器 |
| mech_weapons_2 | heavy | 机械火力中段强化 |
| mech_plating_2 | heavy | 机械承伤中段强化 |
| servo_actuators | heavy | 机械机动与切入能力强化 |
| siege_calibration | heavy | 攻城/远程爆发门槛 |
| drone_link | support | 无人机与辅助链核心前置 |
| air_control | support | 空域控制分支关键点 |
| reactive_shields | support | 阵地防守与前排续航关键点 |
| structure_overclock | support | 建筑网络性能强化 |
| command_matrix | command | 终局会师科技，链接战略级收益 |

### 2.4 技能（20）

技能构成为：
- 建造技能 `5`：对应 5 个新建筑
- 训练技能 `8`：对应 8 个新单位
- 科研技能 `7`：优先覆盖本阶段关键科技触发入口

说明：
- 当前依然是占位与解锁链路优先，不要求全部技能行为脚本立刻实现。
- 行为级技能（主动施放）可放在 Phase-3 再补充表现与数值。

## 3. 解锁链与决策窗口

### 3.1 关键解锁链

1. `support_protocols -> drone_link -> air_control`
2. `precision_targeting -> siege_calibration -> artillery_mech`
3. `quantum_command -> command_matrix -> vanguard / logistics_officer`
4. `infantry_armor_2 -> reactive_shields -> shieldbearer`

### 3.2 决策窗口（玩家感知）

- 窗口 A（T3 刚展开）：
  `drone_bay` 与 `shield_array` 二选一会形成“机动运营”或“阵地稳扎”分歧。
- 窗口 B（T3 成型）：
  `artillery_foundry` 是否优先会决定是打远程攻坚还是先补综合面板。
- 窗口 C（T4 会师）：
  `command_uplink + command_matrix` 决定是否进入全局加成终局节奏。

## 4. 与当前系统的低风险接入方式

本阶段保持“设计与资源层落地为主”，代码层仅建议做可选最小动作：

1. 继续通过 CSV -> `.tres` 生成链路维护单一真源。  
2. 新增条目默认 `status=planned`，不进入现有对局默认可选池。  
3. AI/HUD 只做“可识别字段兼容”，不强行开启使用。  
4. 每个分期单独维护 scope 文件，避免一次性全量接入导致回归。  

## 5. 验收标准（Phase-2）

数据层验收：
- `phase2_buildings.csv` 条数为 `5`
- `phase2_units.csv` 条数为 `8`
- `phase2_techs.csv` 条数为 `10`
- `phase2_skills.csv` 条数为 `20`

设计层验收：
- 与 Phase-1 无重复 ID
- 每个新增建筑都有至少一个对应训练或科研入口
- 每条关键科技链都有明确的战术收益描述

## 6. 建议下一步（Phase-3 预告）

Phase-3 可以优先覆盖：
- `void_core`、`orbital_array` 相关终局条目
- 主动技能行为脚本（如 `orbital_strike`、`psionic_storm`）的最小可视化实现
- AI 编组模板中加入“重装推进流”与“阵地运营流”两个新策略包
