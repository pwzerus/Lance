# DEV-051 德意志12件素材交接

motion_qa生成，built-in imagegen，每件独立调用，沿用eng_helmet_5／eng_armor_5像素风格，历史结构据实际观察的馆藏及同期手稿。详见`docs/research/V051_DE_IT.md`。现有ID0–5保留。未运行Godot，未修改共享manifest或生产渲染器，未提交Git。

## 已交文件与测量

- `game/assets/art/pixel_v051/de_helmet_0..5.png/.json`：6种头盔。鼻护、包头大盔、高尖hounskull、长尾sallet与护颏、沟槽风箱闭盔、三脊敞脸burgonet。头盔0/5为开放脸口，JSON给出人工测量的归一化脸矩形。
- `game/assets/art/pixel_v051/de_armor_0..5.png/.json`：锁甲、双色纹章布罩袍锁甲、箱式V槽胸甲、哥特弧槽叠腰甲、密沟槽圆胸甲、洛赫纳式银卷草金边胸甲。
- 本目录各件`_source01.png/.md`留首版与确切prompt；`de_helmet_2_source02`去掉误生成的后世实心钢护颈并延长鼻锥面罩；`de_armor_0_source02`把鳞片感修改成圆环链。两件最终PNG对应source02，其余source01。
- 全部原生1254×1254，未缩小、未改alpha、未用代码重绘；按alpha≥128测量可见边界，写source_region与SHA256。标称draw_size为盔70×80、甲94×104。
- 静态读取12描述文件、对应PNG存在、散列一致、裁切非空、脸矩形处于0..1范围通过。24条历史覆盖ID集合和材质字段静态检查通过。

## 取舍与剩余风险

生成图采用易读结构化像素块而非细密照片纹理。原物铆钉与装饰位置、精确曲率没有逐像素复原。鼻护盔附短颊边、sallet护颏比例和部分胸甲领缘偏高属于已记录的简化；须在真实骑手上复核是否压脸、压颈或与抬盾冲突。脸矩形只按源图面口量取，尚未经过Godot实际脸部渲染，不以数值合法代替视觉验收。左右镜像后的非对称透气孔是游戏显示简化，不宣称两侧原物都相同。

早期锁甲省略袖子是为了独立手臂骨架，不是说历史hauberk无袖。罩袍纹章为原创几何纹，非某历史人物身份。盔0/5高档身份与面部防护不是同一变量；敞面高档盔不应靠文字暗示全面优于闭盔。

`de_reference_*.png`是排查图像工具拒读博物馆原图时的临时研究拷贝；均非生成成品，不应放入游戏、生成manifest或发布包。本轮实际原物观察通过同受控Python进程解码显示完成；imagegen因环境解码限制只收到项目风格母图和据原图写的结构brief。不要把未成功送入imagegen的公图写成已用图像参考输入。

root接手后合并每件JSON的image_path/source_region/draw_size/open_face/face_rect/source_sha256进共享equipment_art_v051.json，再统一引擎导入与双向骑手/商店/脸孔/前后倾/抬盾验证。此交接不构成引擎通过或真人体验结论。
