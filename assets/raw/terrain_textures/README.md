# 地形纹理资源包 (Terrain Texture Pack)

## 资源概述

本资源包为Godot引擎地形系统提供完整的PBR纹理支持，包含基础地表、悬崖、变化贴图等共 **32张** 高质量无缝贴图。

---

## 文件统计

| 类别 | 数量 | 大小 |
|------|------|------|
| Albedo | 4张 | 4.51 MB |
| Normal | 4张 | 3.48 MB |
| ORM | 4张 | 3.76 MB |
| Height | 4张 | 21.70 MB |
| Cliff | 12张 | 22.88 MB |
| Macro | 4张 | 5.24 MB |
| **总计** | **32张** | **61.57 MB** |

---

## 目录结构

```
terrain_textures/
├── albedo/          # 反照率贴图 (sRGB)
├── normal/          # 法线贴图 (Linear, OpenGL +Y)
├── orm/             # ORM贴图 (Linear, R=AO/G=Roughness/B=Metallic)
├── height/          # 高度贴图 (Linear, 16-bit)
├── cliff/           # 悬崖贴图 (Y向可平铺)
├── macro/           # 大尺度变化贴图
└── preview_*.png    # 预览图
```

---

## 基础地表贴图 (4层)

### 草地 (Grass)
- `terrain_temperate_grass_albedo_2k.png`
- `terrain_temperate_grass_normal_2k.png`
- `terrain_temperate_grass_orm_2k.png`
- `terrain_temperate_grass_height_2k.png`

### 泥土 (Dirt)
- `terrain_temperate_dirt_albedo_2k.png`
- `terrain_temperate_dirt_normal_2k.png`
- `terrain_temperate_dirt_orm_2k.png`
- `terrain_temperate_dirt_height_2k.png`

### 岩石 (Rock)
- `terrain_temperate_rock_albedo_2k.png`
- `terrain_temperate_rock_normal_2k.png`
- `terrain_temperate_rock_orm_2k.png`
- `terrain_temperate_rock_height_2k.png`

### 沙地 (Sand)
- `terrain_temperate_sand_albedo_2k.png`
- `terrain_temperate_sand_normal_2k.png`
- `terrain_temperate_sand_orm_2k.png`
- `terrain_temperate_sand_height_2k.png`

---

## 悬崖贴图 (3套)

### 悬崖岩石 A
- `terrain_cliff_rock_a_albedo_2k.png`
- `terrain_cliff_rock_a_normal_2k.png`
- `terrain_cliff_rock_a_orm_2k.png`
- `terrain_cliff_rock_a_height_2k.png`

### 悬崖岩石 B
- `terrain_cliff_rock_b_albedo_2k.png`
- `terrain_cliff_rock_b_normal_2k.png`
- `terrain_cliff_rock_b_orm_2k.png`
- `terrain_cliff_rock_b_height_2k.png`

### 悬崖泥土 A
- `terrain_cliff_dirt_a_albedo_2k.png`
- `terrain_cliff_dirt_a_normal_2k.png`
- `terrain_cliff_dirt_a_orm_2k.png`
- `terrain_cliff_dirt_a_height_2k.png`

**悬崖特性**: Y方向垂直平铺，适合竖直壁面

---

## 变化贴图 (Macro/Noise)

| 文件名 | 分辨率 | 用途 |
|--------|--------|------|
| `terrain_macro_color_variation_4k.png` | 4096x4096 | 大尺度颜色变化 |
| `terrain_macro_roughness_variation_4k.png` | 4096x4096 | 大尺度粗糙度变化 |
| `terrain_detail_noise_a_1k.png` | 1024x1024 | 细节噪声A |
| `terrain_detail_noise_b_1k.png` | 1024x1024 | 细节噪声B |

---

## 技术规格

### 格式
- **文件格式**: PNG (无损压缩)
- **禁用**: JPEG (压缩块会破坏无缝)

### 色彩空间
- **Albedo/Color**: sRGB
- **Normal/ORM/Height**: Linear

### 位深
- **Albedo/Normal/ORM**: 8-bit
- **Height**: 16-bit

### 分辨率
- **基础贴图**: 2048x2048 (2K)
- **悬崖贴图**: 2048x2048 (2K)
- **Macro变化**: 4096x4096 (4K)
- **Detail噪声**: 1024x1024 (1K)

### 平铺
- **四边无缝**: 所有tile贴图支持repeat+mipmap
- **悬崖Y向**: 垂直方向可平铺

### Normal方向
- **OpenGL**: +Y方向 (Godot默认)

### ORM通道
- **R**: Ambient Occlusion (环境光遮蔽)
- **G**: Roughness (粗糙度)
- **B**: Metallic (金属度)

---

## Godot导入设置

### Albedo
```
- Import as: Texture2D
- Compress: VRAM Compressed
- Format: sRGB
```

### Normal
```
- Import as: Texture2D
- Compress: VRAM Compressed
- Format: Linear
- Normal Map: Enable
```

### ORM
```
- Import as: Texture2D
- Compress: VRAM Compressed
- Format: Linear
```

### Height
```
- Import as: Texture2D
- Compress: VRAM Uncompressed (保持16位精度)
- Format: Linear
```

---

## 命名规范

```
terrain_<biome>_<layer>_<maptype>_<res>.png

例: terrain_temperate_grass_albedo_2k.png
    │       │        │       │      │
    │       │        │       │      └─ 分辨率 (2k/4k/1k)
    │       │        │       └─ 贴图类型 (albedo/normal/orm/height)
    │       │        └─ 层名 (grass/dirt/rock/sand)
    │       └─ 生态群系 (temperate/desert/arctic)
    └─ 资源类型前缀
```

---

## 使用建议

### 地形混合
1. 使用Height贴图进行基于高度的混合
2. 使用Macro变化贴图打破重复感
3. 使用Detail噪声添加微观细节

### 悬崖应用
1. 根据坡度自动切换地表/悬崖材质
2. 悬崖贴图Y向平铺适合垂直面
3. 使用Normal增加表面凹凸感

### 性能优化
1. 在Godot中启用VRAM压缩
2. 使用mipmap提高远处渲染质量
3. 考虑LOD系统减少远距离贴图分辨率

---

## 生成信息

- **生成日期**: 2026-03-08
- **生成方式**: 程序化生成 (Python + PIL)
- **噪声算法**: 分形布朗运动 (FBM)
- **平铺处理**: 边缘混合技术确保无缝

---

## 许可

本资源包为定制生成，可用于商业项目。
