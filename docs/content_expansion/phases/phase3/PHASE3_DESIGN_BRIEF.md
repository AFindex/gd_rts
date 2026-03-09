# Phase-3 设计说明（终局会师分支）

## 1. 阶段目标

Phase-3 聚焦“终局内容可设计、可占位、可分批接入”，把前两期铺开的中后期分支收束到终局决策。

本阶段固定范围：
- 建筑：`5`
- 单位：`8`
- 科技：`10`
- 技能：`20`

相对 Phase-1/2 的核心变化：
- 从“功能补齐”转向“终局会师与胜负手”。
- 引入 `orbital_array` 与 `phase_manipulation` 相关的高冲击选项。
- 强化“高成本高收益”的上限内容，而不是继续基础件扩容。

## 2. 内容结构

### 2.1 建筑（5）

| id | 层级 | 角色 | 设计价值 |
|---|---|---|---|
| psionic_relay | T2 | 支援/心灵分支入口 | 给终局控场与特战单位提供前置 |
| bio_vat | T3 | 生化重装生产 | 为重装与攻坚单位提供中继 |
| warp_gate | T3 | 机甲生产主入口 | 承接机械分支并衔接终局科技 |
| void_core | T4 | 终局科技/单位核心 | 汇聚多分支，形成终局科技枢纽 |
| orbital_array | T4 | 终局技能建筑 | 提供轨道级技能与地图影响力 |

### 2.2 单位（8）

| id | 分组 | 角色定位 | 战术意义 |
|---|---|---|---|
| infiltrator | infantry | 渗透切后排 | 迫使对手补侦测与阵型保护 |
| guardian | infantry | 高韧性前排 | 为终局火力争取输出窗口 |
| siege_mech | heavy | 攻城主火力 | 结构拆解与阵地突破核心 |
| guardian_tank | heavy | 重装推进前排 | 与护盾/维修体系联动推线 |
| disruptor_walker | heavy | 高科技面伤压制 | 提供范围压制与阵型破坏 |
| commando | special | 终局特战单位 | 点杀关键目标与关键建筑 |
| psionic_adept | special | 控场与干扰 | 放大正面会战的操作空间 |
| warlord | special | 终局统御单位 | 提供战略级编队增益锚点 |

### 2.3 科技（10）

| id | 分支 | 目的 |
|---|---|---|
| infantry_weapons_3 | infantry | 步兵终段火力上限 |
| infantry_armor_3 | infantry | 步兵终段生存上限 |
| heavy_plating | heavy | 重装体系前置强化 |
| mech_chassis | heavy | 机械体系关键解锁前置 |
| mech_weapons_3 | heavy | 机械终段输出上限 |
| mech_plating_3 | heavy | 机械终段承伤上限 |
| precision_targeting | command | 攻坚与高阶打击前置 |
| quantum_command | command | 终局指挥链核心门槛 |
| orbital_targeting | command | 轨道技能解锁前置 |
| phase_manipulation | command | 终局机制级能力 |

### 2.4 技能（20）

技能组成：
- 建造 `1`：`build_orbital_array`
- 训练 `8`：覆盖本期 8 个单位
- 科研 `7`：覆盖终局关键科技与收束节点
- 主动战术 `4`：终局会战关键按钮

主动战术四件：
- `fortify_mode`
- `siege_mode`
- `call_drop_pod`
- `orbital_strike`

这四个技能分别对应：
- 阵地稳态
- 攻城形态切换
- 战术投送
- 终局范围打击

## 3. 终局会师链路

关键链路定义：

1. 机械攻坚链  
   `mech_chassis -> mech_weapons_3 / mech_plating_3 -> siege_mech / guardian_tank`

2. 指挥终局链  
   `precision_targeting -> quantum_command -> orbital_targeting -> orbital_array`

3. 高科技压制链  
   `quantum_command -> phase_manipulation -> disruptor_walker / psionic_adept`

4. 终局编队链  
   `command_matrix (Phase-2) + 本期终局单位` 形成最终阵容上限

## 4. 单位定位分级（Phase-3）

分级用于后续平衡与 AI 生产优先级：

- `S`（胜负手）：`disruptor_walker`、`warlord`、`orbital_strike(技能)`
- `A`（主力）：`siege_mech`、`guardian_tank`、`commando`
- `B`（功能核心）：`guardian`、`psionic_adept`
- `C`（战术补位）：`infiltrator`

说明：
- 该分级是设计预估，不代表最终数值强度。
- 后续应按对局数据（胜率、出场率、转折率）迭代。

## 5. 最小接入与风险控制

接入策略：

1. 先维持 `planned` 状态，不直接进入默认对局池。  
2. 先接 UI 可见与解锁链显示，再接行为效果。  
3. 主动技能先实现占位与冷却框架，再逐个补表现与数值。  
4. AI 先支持“可生产/可研究识别”，暂不做复杂施法策略。  

主要风险：

- 风险：终局内容堆叠导致前中期价值被稀释。  
  控制：提高终局门槛与机会成本，确保前中期决策仍重要。

- 风险：终局技能爆发导致对局波动过大。  
  控制：增加预警、施法延迟、反制窗口。

- 风险：多分支会师导致学习成本陡升。  
  控制：分期放开，先开放一条终局链进行灰度验证。

## 6. 验收标准（Phase-3）

数据验收：
- `phase3_buildings.csv` = `5`
- `phase3_units.csv` = `8`
- `phase3_techs.csv` = `10`
- `phase3_skills.csv` = `20`

一致性验收：
- 与 Phase-1/Phase-2 无 ID 重复
- 终局链可从现有分支前置推导到达
- 每个终局建筑至少绑定一个可见战术收益
