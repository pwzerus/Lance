# v0.4.1 像素资产

2026-10-26，Codex调用image_gen生成，原件保留在用户的`.codex/generated_images/01a16537-8b7f-7df0-9b98-d350cd639afb/`。不是逐像素人工绘制或馆藏复原。两张PNG复制原件后由Godot区域UV、挂点和骨骼动画集成；未用脚本重绘位图。

- `game/assets/art/pixel_v041/nasal_head.png`：1086×1448，RGBA，角点alpha=0。生成ID `exec-ca6934b0-f97a-4f39-bf18-946012996ea8`。参考旧nasal_head.png，脸部改为粗像素块，保留鼻盔及锁子甲识别。
- `game/assets/art/pixel_v041/horse_atlas.png`：1774×887，RGBA，角点alpha=0。生成ID `exec-7a00ce67-4b13-49c7-8a28-b47948486c67`。参考旧rider_atlas调色及马具，生成独立躯干、颈头、尾、蹄及四种腿件。生成器没有严格遵循等宽格子，因此集成使用实际区域及关节坐标，不直接按格切图。

完整提示词见同目录PROMPTS.md。游戏内比例、关节、区域和朝向见`game/scripts/visual/horse_art.gd`、`horse_gait.gd`和`rider_view.gd`；它们才是实际集成规格。

## 动作依据与改编边界

- [University of Minnesota Veterinary Anatomy: Transverse Gallop](https://vanat.ahc.umn.edu/gaits/transGallop.html)：四拍、一次腾空，后肢后肢前肢前肢落地，前后躯轻微俯仰。用于步序，未复制其美术。
- [Montana State University Extension: Horse Locomotion](https://animalrangeextension.montana.edu/equine/locomotion.html)：慢跑采用对角配对，快跑拆开步拍并有腾空。用于动画节奏，未将页面速度数字作为游戏的现实单位。

本作的尺寸、简化两骨加蹄关节、步频和抬腿高度为可读性改编；不是马匹生物力学仿真。马具为1100–1300主题的通用游戏组件，不因配上晚期骑手便宣称复原了晚期贵族整套马铠。
