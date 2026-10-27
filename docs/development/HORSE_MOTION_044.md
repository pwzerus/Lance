# DEV-044：马匹运动参考与诊断

开始2026-10-27 23:44:45 UTC，上限2026-10-28 01:44:45 UTC，基线6ee235e。用户真实反馈：盾手左右反、两臂比例不一致，马像拼装摆腿，速度分档／上下与前后躯动作不明显，松手应减速。

初步代码诊断：
- 旧步态只有巡航210到冲刺480的一个混合系数；身体上下量仅约4–11，远景进一步缩小。起跑直接赋210，无低速起步阶段。
- 近侧上腿在马身之后绘制，圆形裁切接头压在马身外面，强化机械铰链观感。
- 右侧枪臂38/42、另一臂52/58，盾臂挂在后侧肩(-28)却跨胸前伸；远近臂职责／遮挡和正面盾后的握带混乱。
- 鼠标按下设置2秒spur_left，松开仍持续boost，不符合本次用户要求。

参考（仅记录实际读到／看到的内容）：
- University of Minnesota Veterinary Anatomy，Transverse Gallop：https://vanat.ahc.umn.edu/gaits/transGallop.html 。已读四拍／一次腾空、后肢推进与前后躯俯仰说明，浏览器看了步序动画；该页是示意动画，不是真马视频。
- Montana State University Extension，Horse Locomotion：https://animalrangeextension.montana.edu/equine/locomotion.html 。已读walk四拍无腾空、trot对角配对、canter三拍及gallop分开对角步拍；用于区别步态，不复制现实速度为游戏数值。
- GDC，Making the Believable Horses of Red Dead Redemption II：https://gdcvault.com/play/1027230/AI-Summit-Making-the-Believable 。检索确认原开发者演讲，实际页面维护、PDF403；未声称看完或知道其内部算法。
- Library of Congress，Muybridge真实连续摄影：https://www.loc.gov/item/2005684184/ 。浏览器安全验证，未绕过，尚未看到原图；不把检索摘要当作影像观察。
- Science Museum Group，藏品1990-5037/PB16，The Horse in Motion：https://collection.sciencemuseumgroup.org.uk/objects/co8452654/the-horse-in-motion 。浏览器实际查看了二十相位的骑马连续摄影图版：伸展、收腿、支撑与腾空并非同一张马身配四根摆腿。页面深度缩放瓦片报错，但回退图版可见。仅作运动参考，不复制馆藏图片到游戏资产。
- UC Davis Veterinary Orthopedic Laboratory：https://vorl.vetmed.ucdavis.edu/equine-gait-analysis 。原站链接实验室跑台疾驰和高速度蹄部影像，视频mVgFDm2pLzI；影像观看状态在后续记录。

第一轮实现：四种步序与周期关键姿态；躯干、颈头、尾部和骑手相位随动；大腿近端放到马身后遮挡，支撑蹄世界锁定；两臂统一44/46并改为后侧右枪、前侧左盾。身体位移进入同一规则挂点。起跑从0，催马渐进加速到480，松手下一步开始减速，约1.4秒回巡航210；具体数值是游戏调校。

motion-controls-01暴露两项：左向横摆没有镜像（真实代码问题，已修复mount_origin）；GUI按钮注入把逻辑坐标当物理窗口坐标（测试问题，改Viewport逻辑注入）。motion-controls-02通过，步态躯干高度范围约3/13/23/30游戏单位。此数字只说明可辨分档，外观仍需运行和玩家确认。
