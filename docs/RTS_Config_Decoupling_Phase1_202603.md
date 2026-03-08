# RTS 配置解耦（Phase 1-2）

## 目标
- 将原先集中在 `scripts/core/rts_catalog.gd` 的大字典逐步拆分到 `res://config/`。
- 逐步替换运行时读取入口，最终移除旧 catalog 常量依赖。

## 当前已落地
- 新增配置资源类型：
  - `scripts/core/config/rts_unit_config.gd`
  - `scripts/core/config/rts_building_config.gd`
  - `scripts/core/config/rts_tech_config.gd`
  - `scripts/core/config/rts_skill_config.gd`
- 新增注册器：
  - `scripts/core/config/rts_config_registry.gd`
- 新增运行时数据门面：
  - `scripts/core/config/rts_runtime_catalog.gd`
- 新增批量导出脚本：
  - `scripts/core/config/export_catalog_to_config.gd`
- 新增配置校验脚本：
  - `scripts/core/config/validate_config_catalog.gd`
- 新增一键流水线脚本（Windows）：
  - `scripts/core/config/run_config_pipeline.cmd`
  - `scripts/core/config/run_config_pipeline.ps1`
- 运行时核心脚本（`game_manager` / `unit` / `building` / `enemy_ai_manager`）已改为读取：
  - `scripts/core/config/rts_runtime_catalog.gd`
- 导出脚本已改为基于 `RTSConfigRegistry` 读取 `config/*.tres`，不再依赖旧 catalog 常量。
- `scripts/core/rts_catalog.gd` 与 `.uid` 已删除。
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
2. 将对局规则（`MATCH_SETTINGS` / `MATCH_RULE_DEFS`）也拆分为独立配置资源，进一步减少脚本内常量。
3. 给配置流程增加“未引用资源检测”和“技能热键冲突检测”，减少后续联调成本。
