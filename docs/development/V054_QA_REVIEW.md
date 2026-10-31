# DEV-054 像素脸 QA 与独立代码复核

2026-10-30 EDT，face_qa054子代理。负责新增`game/tests/test_face_design_v054.gd`，只读复核生产`character_face.gd`；没有修改生产代码、没有运行Godot或操作桌面。下列引擎结果来自root实际运行后，本代理读取的日志/JSON和PNG，不冒充本代理亲自试玩。

## 夹具与证据含义

新夹具继承v048的等待绘制、截图和检查辅助，最初直接调用生产`draw_face`及`main.show_character()`；头像专用入口加入后由root改为实例化生产`main.CharacterFaceCanvas`，保持与当前编辑器实际入口一致，没有复制五官几何作为“正确答案”。每轮10图：实际自建UI默认、草稿、保存后重开；四脸型无胡须双向的192×240原UI尺寸与8倍网格；六肤色、五胡须、五瞳色、四眉毛、四发色逐项变化。角色预览固定既有idle相位，仍用生产骑手绘制。

`-- --test-profile`与实际GPU显示必须同时满足；report或截图目录已存在则拒绝覆盖。存读档使用每次新建的`user://qa_face_v054_<ticks>.json`，保存并恢复原QA内存和路径。通过真实OptionButton信号检查草稿、取消、保存、重新读档；原正式存档不在夹具路径中。成功仅代表实际图片保存和这些UI/存档接口成立，不表示美术获玩家认可。UI信号不是OS鼠标操作。

## 初轮实际结果复核

- `face-baseline01`：root用实际v0.4.13 EXE运行新夹具。日志明确v0.4.13、10图完成；JSON空failures。实际看默认UI与四脸型原尺寸图，方框眼、亮L鼻、大片平脸和矩形裸颈可复现用户的负面观感。
- `wear01`：root的新生产脸首轮佩戴。查看铁帽2×特写，近眼出现半闭/疲惫观感，已向root报告，不能因佩戴连通或12图保存而通过美术。
- `face02`：root内移瞳孔后的实际GPU自建UI，10图、空failures，日志未见ERROR/WARNING。查看默认UI、四脸型双向、全部肤色/瞳色/胡须图：选择差异仍可见；瞳色没有被后绘制的肤色或眉眼覆盖。默认脸仍偏半眯，长矩形裸颈仍强化木偶感。已建议root进一步处理仅头像路径的短颈和肩部，等待后续图，不提前写最终通过。

## 已核对的代码边界

- 原六肤色、五瞳色、四发色数组与Appearance选项/索引保持；`sanitize`仍在绘制入口。肤色与骑乘颈部共享同一色表，不改变存档结构。
- 四脸型的`face_span`均保持正宽，区分颞部/颧面/下颌而非任意拉伸整个脸框。形状2的脸、眼线和嘴线延长有明确分支；胡须沿既有脸型边界绘制。
- 所有新脸部色块仍通过`block→FaceSurface.draw_rect`进入已有clip；未新增绕过头盔脸孔的直接绘制。朝向仍由外层CanvasItem变换负责，脸部局部坐标统一朝右，没有新增第二次镜像。
- 只读取Appearance与固定色板；绘制没有推进随机流、修改战斗数据或改头部锚点。骑乘调用`include_neck=false`，拟改的头像领部需要保持此区分。

截至face02，未发现明确生产代码兼容阻断；这不等于已接受默认表情。后续最终图与实际包的复核在完成后追加。

## face03失败与face04复核

root为使用生产头像类，把main.gd最初作为const preload引入QA脚本。但命令行SceneTree编译时GameState autoload尚未注册，face03.log明确出现`Identifier not found: GameState`、依赖编译失败及不存在函数；实际3张UI图没有执行，仅产生7张空内容的sheet，旧report仍写passed=true。此轮是失败，不能用JSON结果或引擎退出替代日志/图像检查。root保留原失败日志，改为run中验证GameState后动态load，并验证can_instantiate与10图完整。

本代理读取face04.log/JSON：实际10图、空failures，日志未见同类错误。只读检查当前QA，dynamic load确在autoload检查后，load失败会退出；旧PCK与新源码都从实际生产CharacterFaceCanvas拿到各自头像，不存在QA独立替代画法。仍须审计引擎日志，截图数本身不保证每张图内容正确。

实际看face04的默认UI、四脸型双向和肤色/眼色/胡须图。短颈肩衣降低木偶感，眼裂局部增加一行后瞳色和视线较前轮清晰；未再见旧方框眼与大亮L鼻。但发现以下实质问题，已要求修复：

- **P2，已修复：头像肩衣覆盖长胡须末端。** 初版`draw_portrait`先draw_face（长须到row36、窄长脸山羊胡可到row35），再从row34绘制肩衣。face04/choices_beard.png长须出现水平截断，face02原图可见收尖。报告后root改为肩衣/短颈先画，脸和胡须以include_neck=false最后画；face05复核见下。
- 头像与legacy分离已核对：main.CharacterFaceCanvas调用新draw_portrait，RiderView和fallback draw_head仍调用draw_face，肩衣不会进入骑乘头盔脸孔。

## face05 / wear04 最终源码复核

本代理再次只读当前`draw_portrait`和调用链：短颈、肩衣与前领先绘制，最后`draw_face(canvas,appearance,rect,Rect2(),false)`绘制脸和全部胡须。根本移除了衣领覆盖任何脸型胡须的顺序条件；窄长脸山羊胡虽未额外生成单独特写，其较低末端也在衣领之后绘制，不再受到旧覆盖。实际看face05/choices_beard.png，长胡须末端重新在领口前收窄，未再呈face04齐领口水平截断。默认UI短颈与衣领保持，未出现第二条长颈。

读取face05日志和JSON：10图完成、空failures，未见ERROR/WARNING/SCRIPT ERROR；wear04日志12图完成无同类错误。实际查看wear04/dark_skin_high_collars.png的深肤色、双向、高领及封闭盔：脸部肤色仍与颈一致，没有头像肩衣泄漏到盔甲区域；封闭盔按既有遮挡显示。此前检查过的眼色、眉须索引以及UI草稿/保存/重开保持。

**此次源码审查范围内，没有剩余明确代码阻断；P2头像胡须层级问题已经静态和实际图复核修复。** 人物表情好看与否由独立美术审查和用户继续判断，本报告不作“正常脸”通用审美保证。没有穷举所有脸型×肤色×胡须×头盔组合，没有实际操作鼠标或真人试玩；实际v0.4.14导出包、全装备姿态与动态验证由root随后记录，未提前记通过。

QA脚本及本文已交回root，后续不再占用文件。本代理未执行引擎、Git提交或触碰正式档。
