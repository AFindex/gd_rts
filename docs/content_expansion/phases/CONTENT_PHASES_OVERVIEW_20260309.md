# RTS 内容扩容分期总览（2026-03-09）

## 1. 总体结论

四期分包已经覆盖主占位表的全部内容，且跨期无重复 ID。

覆盖对账：
- 建筑：`22 / 22`
- 单位：`34 / 34`
- 科技：`36 / 36`
- 技能：`84 / 84`

重复校验：
- 建筑重复：`0`
- 单位重复：`0`
- 科技重复：`0`
- 技能重复：`0`

## 2. 分期范围

| Phase | 建筑 | 单位 | 科技 | 技能 | 主题 |
|---|---:|---:|---:|---:|---|
| Phase-1 | 5 | 8 | 10 | 20 | 中期开枝与第一批战术件 |
| Phase-2 | 5 | 8 | 10 | 20 | 支援重装协同与中后期成型 |
| Phase-3 | 5 | 8 | 10 | 20 | 终局会师与胜负手 |
| Phase-4 | 7 | 10 | 6 | 24 | 基础主干与剩余池收口 |
| 合计 | 22 | 34 | 36 | 84 | 全量覆盖 |

## 3. 当前资产与脚本

导出脚本：
- `scripts/core/config/export_phase1_subset_from_placeholders.ps1`
- `scripts/core/config/export_phase2_subset_from_placeholders.ps1`
- `scripts/core/config/export_phase3_subset_from_placeholders.ps1`
- `scripts/core/config/export_phase4_remaining_from_placeholders.ps1`

分期目录：
- `docs/content_expansion/phases/phase1/`
- `docs/content_expansion/phases/phase2/`
- `docs/content_expansion/phases/phase3/`
- `docs/content_expansion/phases/phase4/`

每期均包含：
- `phaseN_buildings.csv`
- `phaseN_units.csv`
- `phaseN_techs.csv`
- `phaseN_skills.csv`
- `PHASEN_SCOPE.md`
- `PHASEN_DESIGN_BRIEF.md`

## 4. 建议接入顺序（低风险）

1. 默认启用 Phase-4（基础主干）作为可玩底盘。  
2. 灰度接入 Phase-1，验证中期分支与技能栏容量。  
3. 再接入 Phase-2，验证中后期节奏和 AI 编队稳定性。  
4. 最后接入 Phase-3，重点压测终局技能与会战波动。  

## 5. 复跑命令

全量占位转 `.tres`（staging）：
```powershell
powershell -ExecutionPolicy Bypass -File "scripts/core/config/generate_expansion_placeholders_from_csv.ps1" -Clean
```

分期导出：
```powershell
powershell -ExecutionPolicy Bypass -File "scripts/core/config/export_phase1_subset_from_placeholders.ps1"
powershell -ExecutionPolicy Bypass -File "scripts/core/config/export_phase2_subset_from_placeholders.ps1"
powershell -ExecutionPolicy Bypass -File "scripts/core/config/export_phase3_subset_from_placeholders.ps1"
powershell -ExecutionPolicy Bypass -File "scripts/core/config/export_phase4_remaining_from_placeholders.ps1"
```
