# RTS Enemy AI 配置说明（多策略版）

## 1) 目标

当前敌方 AI 已升级为 **双层配置驱动**：

- 数据层：`res://scripts/core/rts_ai_catalog.gd`
- 执行层：`res://scripts/core/enemy_ai_manager.gd`

执行层不再只做固定波次，而是：

1. 先读 `profile` 的基础配置（生产 / 经济 / 战术）。  
2. 再按实时上下文（时间、兵力、资源、前线压力）切换 `strategy mode`。  
3. 把 mode 的 `overrides` 合并为当前生效配置。  

---

## 2) 当前能力概览

### 2.1 战略层（新）

- 支持 `strategy.modes[]` 多策略集合。
- 支持 `priority` 优先级竞争。
- 支持 `hold_seconds` 持续锁定，避免策略抖动。
- 支持条件窗口（`when`）：
  - `min_/max_match_time`
  - `min_/max_team_workers`
  - `min_/max_team_combat_units`
  - `min_/max_enemy_workers`
  - `min_/max_enemy_combat_units`
  - `min_/max_enemy_pressure`
  - `min_/max_team_minerals`
  - `min_/max_team_gas`
  - `min_/max_wave_threshold`

### 2.2 战术层（新）

`combat.engagement_mode` 支持：

- `wave`：原有集结-出征-撤退波次逻辑。
- `defend`：优先清理基地半径内入侵，默认守势。
- `harass`：抽取小队优先骚扰 worker。
- `all_in`：达到阈值后全军持续压制。

### 2.3 生产层（增强）

- 支持通用兵种训练：优先调用 `queue_unit(unit_kind)`。
- 支持矿/气双资源扣费与失败回滚。
- 支持 `orders[]` 内条件窗口（同 `min_/max_*` 规则）。

### 2.4 经济层（增强）

- `preferred_resource_type = minerals / gas / auto`
- `auto_prefer_gas_below`：自动模式下低气优先采气。
- `allow_resource_fallback`：无目标资源类型时是否回退采其他资源。

---

## 3) Profile 结构（核心字段）

```gdscript
{
  "tick_rates": {
    "production": 3.0,
    "tactical": 0.85,
    "economy": 1.0,
    "strategy": 1.0
  },
  "production": { ... },
  "economy": { ... },
  "combat": { ... },
  "strategy": {
    "enabled": true,
    "min_hold_seconds": 8.0,
    "default_mode_id": "balanced_frontline",
    "modes": [
      {
        "id": "hold_under_pressure",
        "priority": 120,
        "hold_seconds": 9.0,
        "when": { "min_enemy_pressure": 3 },
        "overrides": {
          "production": { ... },
          "combat": { ... }
        }
      }
    ]
  }
}
```

---

## 4) 已内置 profile

- `enemy_default`：自适应平衡（开局运营 / 压力防守 / 中期推进 / 后期 all-in）。
- `enemy_rush`：快攻导向（高频骚扰 + 早期强压）。
- `enemy_turtle`：防守反击导向（守势积兵 + 后期突破）。

---

## 5) 与旧参数兼容

`EnemyAI` 节点仍保留 legacy 参数：

- `train_interval`
- `wave_interval`
- `min_units_for_wave`
- `train_per_cycle`

当 `use_legacy_property_overrides = true` 时，这些值会覆盖 profile 的部分字段。  
若要完全由 profile/strategy 接管，请关闭它。

---

## 6) 快速新增一个策略模式

在某个 profile 的 `strategy.modes` 中追加：

```gdscript
{
  "id": "midgame_harass",
  "priority": 85,
  "hold_seconds": 8.0,
  "when": {
    "min_match_time": 160,
    "min_team_combat_units": 5,
    "max_enemy_pressure": 2
  },
  "overrides": {
    "combat": {
      "engagement_mode": "harass",
      "target_mode": "workers_first",
      "harass_squad_size": 5
    },
    "production": {
      "orders": [
        {"unit_kind": "soldier", "per_cycle": 2, "max_team_units": -1, "building_roles": ["barracks", "warp", "vat", "core"]}
      ]
    }
  }
}
```

---

## 7) 调试建议

- 打开 `EnemyAI.debug_ai_log`。
- 观察策略切换日志：
  - `strategy -> <id>`
  - `engagement_mode -> <mode>`
- 若出现频繁切换，优先调大 `min_hold_seconds / hold_seconds`，并收紧 `when` 条件窗口。
