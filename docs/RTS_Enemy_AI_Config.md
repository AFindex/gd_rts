# RTS Enemy AI 配置说明

## 1) 目标

当前敌方 AI 已改为「配置驱动」：

- **数据层**：`res://scripts/core/rts_ai_catalog.gd`
- **执行层**：`res://scripts/core/enemy_ai_manager.gd`

`enemy_ai_manager.gd` 不再写死训练/进攻节奏，而是读取 profile 决策。

---

## 2) 现在敌方如何使用

场景节点 `Main/EnemyAI` 已接入新系统：

- `script = res://scripts/core/enemy_ai_manager.gd`
- `ai_profile_id = "enemy_default"`

并且为了兼容旧参数，默认开启：

- `use_legacy_property_overrides = true`

这意味着你在场景里旧的这些字段仍会生效并覆盖 profile 对应值：

- `train_interval`
- `wave_interval`
- `min_units_for_wave`
- `train_per_cycle`

如果想完全由 profile 控制，把 `use_legacy_property_overrides` 关掉。

---

## 3) Profile 在哪里配

编辑文件：`res://scripts/core/rts_ai_catalog.gd`

核心结构如下：

```gdscript
const BASE_PROFILE: Dictionary = {
  "tick_rates": {
    "production": 3.2,
    "tactical": 0.9
  },
  "production": {
    "max_queue_per_building": 2,
    "orders": [
      {
        "unit_kind": "soldier",
        "per_cycle": 1,
        "max_team_units": -1,
        "building_roles": ["barracks", "warp", "vat", "core"]
      }
    ]
  },
  "combat": {
    "wave_cooldown": 10.0,
    "base_wave_size": 3,
    "growth_step": 1,
    "growth_interval": 75.0,
    "max_wave_size": 12,
    "retreat_ratio": 0.35,
    "rally_distance": 10.0,
    "attack_order_mode": "attack_move",
    "regroup_order_mode": "move",
    "attack_order_refresh": 1.2,
    "regroup_order_refresh": 1.2,
    "target_priority_building_kinds": ["base", "barracks", "tower", "*"],
    "fallback_to_units": true,
    "ignore_worker_targets": false
  }
}
```

---

## 4) 字段含义（简版）

- `tick_rates.production`: 生产决策频率（秒）
- `tick_rates.tactical`: 战术决策频率（秒）
- `production.max_queue_per_building`: 单建筑最多允许多少排队项
- `production.orders[]`: 训练规则列表（按顺序执行）
- `orders[].unit_kind`: `soldier` / `worker`
- `orders[].per_cycle`: 每次生产 tick 想训练多少个
- `orders[].max_team_units`: 该兵种全队上限，`-1` 表示不限制
- `orders[].building_roles`: 允许执行该训练的建筑角色过滤
- `economy.enabled`: 是否启用工人经济调度
- `economy.worker_order_refresh`: 给工人重发采集命令的最小间隔（秒）
- `economy.max_resource_search_distance`: 工人寻找矿点的最大半径
- `combat.wave_cooldown`: 两次开团之间的最短间隔（秒）
- `combat.base_wave_size`: 最小开团人数
- `combat.growth_step`: 随时间增长的波次规模增量
- `combat.growth_interval`: 每经过多少秒增长一次
- `combat.max_wave_size`: 波次规模上限
- `combat.retreat_ratio`: 当前兵力低于“出征兵力 * 比例”则撤回集结
- `combat.rally_distance`: 集结点距离己方锚点的前推距离
- `combat.attack_order_mode`: `attack_move` 或 `attack`
- `combat.regroup_order_mode`: `move` 或 `attack_move`
- `combat.attack_order_refresh`: 同一单位重发攻击指令的最小间隔（秒）
- `combat.regroup_order_refresh`: 同一单位重发集结指令的最小间隔（秒）
- `combat.target_priority_building_kinds`: 建筑目标优先级（支持 `*`）
- `combat.fallback_to_units`: 没建筑目标时是否打单位
- `combat.ignore_worker_targets`: 打单位时是否忽略 worker

---

## 5) 快速新增一个 AI 风格

在 `PROFILE_OVERRIDES` 里新增条目，例如：

```gdscript
"enemy_midgame_push": {
  "tick_rates": { "production": 2.8, "tactical": 0.7 },
  "production": {
    "orders": [
      { "unit_kind": "soldier", "per_cycle": 2, "max_team_units": -1, "building_roles": ["barracks", "warp", "vat", "core"] }
    ]
  },
  "combat": {
    "wave_cooldown": 8.0,
    "base_wave_size": 4,
    "growth_step": 1,
    "growth_interval": 60.0
  }
}
```

然后在 `Main/EnemyAI` 把 `ai_profile_id` 改成：

`"enemy_midgame_push"`
