# RTS 配置解耦（Phase 1-2）

## 目标
- 将原先集中在 `scripts/core/rts_catalog.gd` 的大字典逐步拆分到 `res://config/`。
- 保留旧常量作为兼容兜底，避免一次性迁移导致联动风险。

## 当前已落地
- 新增配置资源类型：
  - `scripts/core/config/rts_unit_config.gd`
  - `scripts/core/config/rts_building_config.gd`
  - `scripts/core/config/rts_tech_config.gd`
  - `scripts/core/config/rts_skill_config.gd`
- 新增注册器：
  - `scripts/core/config/rts_config_registry.gd`
- 新增批量导出脚本：
  - `scripts/core/config/export_catalog_to_config.gd`
- 新增配置校验脚本：
  - `scripts/core/config/validate_config_catalog.gd`
- 新增一键流水线脚本（Windows）：
  - `scripts/core/config/run_config_pipeline.cmd`
  - `scripts/core/config/run_config_pipeline.ps1`
- `rts_catalog.gd` 已改为：
  - 优先读取 `RTSConfigRegistry` 的配置结果。
  - 若未命中则按开关决定是否回退到旧常量字典。
  - 开关路径：`application/config/rts_catalog_enable_legacy_fallback`（默认 `true`）。
- 建造成本链路升级为通用资源字典（minerals/gas）：
  - 放置、确认、排队建造、失败回滚、取消退款均支持双资源。

## 目录约定
- `config/units/*.tres`
- `config/buildings/*.tres`
- `config/techs/*.tres`
- `config/skills/*.tres`

## 已迁移状态
- 已通过导出脚本批量生成：
  - `config/units/*.tres`（11）
  - `config/buildings/*.tres`（11）
  - `config/techs/*.tres`（10）
  - `config/skills/*.tres`（51）
- 导出命令：
  - `godot --headless --path . --script scripts/core/config/export_catalog_to_config.gd`
- 校验命令：
  - `godot --headless --path . --script scripts/core/config/validate_config_catalog.gd`
  - 成功返回 `0`，失败返回 `1` 并打印错误列表（包含引用链和来源文件）。
- 一键流水线（推荐）：
  - `cmd /c scripts\\core\\config\\run_config_pipeline.cmd`
  - 常用参数：`--skip-export`、`--skip-smoke`、`--godot <exe>`、`--project <path>`

## 下一步建议
1. 在 CI 或启动前流程中固定执行配置校验脚本，防止坏配置进入主分支。
2. 分阶段将 `application/config/rts_catalog_enable_legacy_fallback` 切为 `false` 做联调。
3. 验证通过后删除 `rts_catalog.gd` 旧常量，保留纯资源驱动。
