# DEV-053 独立代码复核

2026-10-30 EDT，head_qa053子代理。只读复核root相对25a2a04的`head_fit.gd`、`rider_view.gd`、`fallen_rider.gd`及`equipment_fit_v052.json`；本代理没有修改生产文件、没有启动Godot。另由本代理编写的佩戴夹具属于QA实现，不能将其开发者身份当成真人独立试玩。

## 实质发现

1. **P2，已静态定位并修复：受击时领口覆绘没有跟随胸甲表面。** 初始`head_fit.gd::draw_collar_lip`直接画局部矩形，而`rider_view.gd::_draw_impact_torso`所有顶点会经过`_torso_surface_point`的受击横向压缩。命中且`impact_recoil>0`时，领口附近胸甲会移动约2–3游戏像素，覆绘仍停在旧位置，可能产生错缝/双边。已向root报告；root改为通过Callable复用同一表面函数，只变顶点，UV仍对应原素材。静态复核调用与参数一致；最终实际受击图由root复验。

2. **P2，引擎日志已复现并修复：颈阴影多边形无法三角化。** `logs/v053/allfit01.log`有六条`Invalid polygon data, triangulation failed`，来自初版阴影多边形。该次JSON的`passed=true`只说明夹具断言，不代表无渲染错误；不能据此验收。root将阴影换成简单四边形，并将颈上界限定在底座上方至少6单位，避免低脸孔/高领组合逆序。静态复核当前顶点顺序后未见交叉；需要保留失败日志并用新目录重跑，最终结果由root记录。

## 已核对的边界

- 胸甲固定在三分之四躯干空间；`head_offset`沿未镜像的躯干x轴进入领口，头部自身x基向量才随朝向反转。颈根留在胸甲socket，颈顶跟随朝向，两者的不同空间是有意设计，没有多镜像一次。
- `fallen_rider.body_points()`采用`torso*(point*facing+head_offset)`，与实际`head_transform`绘制等价，未漏加新偏移，也未改变落马规则。帽沿宽度进入视觉落地包络，仍沿用前版矩形近似。
- 新领口覆绘沿原94×104胸甲UV取样，不使用头部朝向镜像。Godot4.5的`CanvasItem::draw_polygon`会将AtlasTexture的UV映射到其region，因此不需要再次手动转换为整个PNG的UV。[Godot4.5引擎源码](https://raw.githubusercontent.com/godotengine/godot/4.5/scene/main/canvas_item.cpp)
- 开放盔才绘制肤色脸与颈部；封闭盔维持灰色衬领并由原盔图遮挡。肤色索引经`Appearance.sanitize`，仍使用同一肤色表。旧装备别名由Catalogue解析为实际art ID，新数据不写存档结构或装备属性。
- 头部规则锚点仍为躯干局部(0,-111)，头部命中圆半径仍24。本轮增加约3–5单位的视觉横移，规则没有相应位移；这是需要实际命中图核对的小幅美术校准，不是完整轮廓碰撞。没有发现大范围坐标分离、枪盾瞬移或伤害逻辑修改。
- `head_fit→character_face→equipment_art`没有形成回到rider_view的循环preload。当前调用处已更新`draw_neck`签名和`draw_collar_lip`的变形参数。

除上述两项外，本次只读范围内未发现应阻止当前修复继续验包的明确代码缺陷。审美结论由另一位美术审查者给出；本报告不以“可编译”或“连通”替代佩戴观感。

## 复验状态

root已运行baseline及candidate01/02/03各11图；此为root提供及本地实际输出可查，不是本代理运行。补充的`dark_skin_high_collars`把更新夹具增加到12图，覆盖最深肤色/无须、铁帽与高领混搭及封闭/近面盔双向。修复后三角化日志、受击领口连续性和最终包结果待root追加到总验证记录。
