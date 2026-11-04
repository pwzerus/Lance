# ART-060 共用马匹外观

三张独立AI生成贴图，加上原有bay，共四套外观；四国共用，不新增地域马种或属性档。

| 贴图 | 外观 | 生成源文件（保留原件） |
| --- | --- | --- |
| grey.png | 灰斑、深鬃尾、深色下肢 | exec-0687e833-95ad-4471-98db-1021e051880c.png |
| flaxen.png | 浅鬃栗色、臀部细斑、前白袜 | exec-67944000-41f9-42d4-beed-389b0f37654f.png |
| black.png | 黑色、窄面白斑、后白袜 | exec-e40a5341-53a4-4644-ab03-533585a25001.png |

生成工具image_gen，日期2026-11-04；参照既有pixel_v050/horse_complete_skin_v050_01.png编辑。不是具体历史品种复原。源画布1536×1024，朝右，原点左上；沿用horse_skin.gd中的SOURCE_SADDLE、HIND、FORE、POLL等挂点、连续蒙皮和近远腿层次。

导入最长边768，无mipmap；UV依据1536×1024源坐标计算，与导入尺寸分离。三个新增RGBA8纹理的单份像素数据合计估算4.5MiB，实际运行总占用待测。纹理由静态字典共享，切换外观不生成新纹理或新网格；原有mounted_pixel shader剔除alpha低于0.5的软边。

静态抽样轮廓IoU约98%，并非精确逐像素相同。2026-11-04 ART-060V已完成Godot导入和四外观×双朝向×三速度×四相位的渲染，并以实际战斗连续运动复查。证据与发布范围见docs/development/ART060V_REVIEW.md；不得把生成母版或轮廓统计当作动作质量证明。

首次运行发现旧三份.import是带TSD标记的不可解析内容。已移除并由Godot重新生成标准文本，再设size_limit=768并实际重导入；废弃原prepare_horse_import060.py写配置步骤。
