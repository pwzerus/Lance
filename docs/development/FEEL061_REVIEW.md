# FEEL-061 马匹步态返工 · v0.4.21

2026-11-05，用户授权15:01:37–17:01:37 UTC（纽约10:01:37–12:01:37）两小时，要求更自然的走到跑、减少前后弹跳，不接管屏幕。基线0e603cdc616b1abc2d3fe5fae0a70c716ff9a84f；运行修复e8c7d63，后台QA保护4acf79e，沿用codex/v0.4。以本文末尾最终回执为准，旧版与正式存档保留。

## 诊断与具体修改

现有每条腿已经有四段关节链；单纯增加腿骨数量不会修复时间曲线的突变。本轮保留原连续蒙皮、前后腿不同解剖链和地面支撑，只修改已找到的问题。

| 位置 | 旧行为及原因 | 本轮修改 |
| --- | --- | --- |
| horse_gait._swing_point | 不等时长的Catmull-Rom小段在连接处速度不连续；后蹄超出落点后倒退 | 水平方向单调五次插值；竖直方向两段连续速度曲线，提前离地，逐渐落蹄 |
| RiderView._process | 第一帧已跨过抬蹄时刻，却把该帧当成进度0，晚抬一拍 | 正常离地从实际支撑结束相位计时；超出可达范围而提前离地仍用实际离地相位 |
| horse_gait.leg | 前蹄离地14单位内就取消肩部承重位移；近乎伸直的前腿突然换角度 | 承重位移分布到38单位抬升中；可达边缘加小幅平滑，保留硬范围、骨长和原解剖检查 |
| horse_gait.body | 疾驰大幅垂直升降、前后摇摆抢过了腿部动作 | 减少整体升降和前后俯仰；保留后肢推进、前肢承重、腾空的时序及随速度变化的步频 |
| horse_skin | 头部和长颈一并按逐点权重弯曲，头骨局部也变形 | 增加绕枕部的独立头部转动，头部与颈部平滑衔接；缰绳端点使用同一变换 |

没有新增随机偏枪，没有修改装备速度/稳定性、催马输入、耐力、AI、镜头、伤害和枪盾主动移动限速。马背变化仍经生产Model共享到骑手和命中锚点，因此确定性对局的接触结果可能随姿态细微变化。

## 对照与失败保留

所有原始记录位于`logs/feel061-*`，每轮独立路径。固定60Hz状态轨迹对比旧源码与最终F候选，稳态统计忽略前120帧：

| 指标（游戏坐标，不是现实厘米） | v0.4.20基线 | F候选 |
| --- | ---: | ---: |
| 慢步马身升降范围 | 3.00 | 3.00 |
| 小跑马身升降范围 | 6.51 | 4.01 |
| 跑步马身升降范围 | 10.15 | 5.91 |
| 疾驰马身升降范围 | 12.16 | 6.69 |
| 疾驰远侧后蹄最大相邻帧位移 | 23.88 | 11.12 |
| 疾驰近侧后蹄最大相邻帧位移 | 23.10 | 11.60 |
| 曲线内部连接处速度差探针最大值 | 79.01 | 0.81 |

曲线探针对旧Gait实际失败：过冲、反向、连接处速度突变及起落端点速度跳变；新Gait通过。它是回归证据，不是自然度评分。部分慢步后腿峰值并未改善（约7.4→8.1单位/帧），不能声称所有动作指标都下降。实际10匹马30/60/120Hz的原有关节/着地检查均通过。

- trace-a：初次补丁混用空格与tab导致解析失败，修复后重新执行，失败日志保留。
- trace-b：对称sin²抬蹄太晚，增加可达边界钳制，已放弃；采用提前抬升的连续曲线。
- skin01：测试常量名Skin与引擎类同名，修正为CoatSkin后skin02完成。
- 保护器曾拒绝内存余量不足的标准渲染启动；未关闭工作软件，未降低常规游戏上限或系统保留线。
- 图集测试漏设fighter.gait_moving，远腿躯干输入和近腿不同；修正测试夹具，生产预览和战斗原本设置该状态。

## 验证证据与边界

| 检查 | 证据 | 实际范围 |
| --- | --- | --- |
| 原有解剖/脚锁定 | anatomy02、catalogue01 | 4步态、双朝向、30/60/120Hz；十匹马实际属性、按住/松开/再按、跨轮复位；原阈值未放宽 |
| 低更新率 | lowrate01 | 同一检查在20/24/48Hz；通过不等于低帧率视觉丝滑 |
| 不均匀帧率与频繁催马 | cadence-package01 | 实际包生产Model固定120Hz、画面更新20–120Hz不等间隔，三项代表坐骑属性、双方向，每组10秒/30次催马开关；沿用原解剖和脚锁定阈值，最大支撑滑动0.00390625游戏单位，无GPU/OS输入 |
| 可控瞄准与时序 | control01、timing01 | 十匹马共享马背锚点及补偿检查；慢动作/空枪/暂停/枪盾限速；不是OS操作 |
| 专项回归 | regression01、regression-baseline01 | 连续速度、落点不倒退、头骨长度稳定、缰绳锚点一致；2173顶点/1主网格表面不增长 |
| 连续实际渲染 | continuous01、render-f | 真实Rider逐帧、两方向；检查慢步、跑步、疾驰、起步关键帧与疾驰连续10帧；未见透明断缝或后蹄倒甩 |
| 实际发布包连续渲染 | continuous-before02、continuous-package01 | 外部同一QA脚本分别加载.20/.21的PCK；各480帧/16秒，固定30FPS离线录像，不据此宣称实时FPS |
| 真实生产对冲 | fullcharge-package01 | Main/Battle正常process/physics、4400初始间距、正常练习AI、满血；引擎派发按住/松手/再按/换防/调枪；12.38秒完成首轮，2次真实胸部接触，检查通过 |
| 四套外观与生命周期 | coats-package01/02、close-wasapi01 | 四套连续场景、20秒最小化、恢复、QA保存关闭；Dummy占位音频驱动有ObjectDB退出警告，实际WASAPI仅静音本进程的同场景67.4秒检查正常退出且无该警告。没有为此修改生产音频代码 |
| 四套实际包图集 | gallery-package02 | 修正夹具后96姿态；左右方向、站立/小跑/疾驰及四相位；检查近远侧腿和头颈连接，静态相位不替代连续动作 |
| 结算冻结 | terminal-package01 | 两个固定相位、双朝向、结果画面及60帧冻结；新增head自由度纳入模型/渲染一致性，实际发布包通过 |
| 长时对冲/重开 | replay-long01 | 实际包313.8秒、六次重开、交替竞技场/实战、QA保存关闭；峰值664.7MiB，资源计数恒85，正常退出并关闭隔离桌面 |
| 长时最小化/恢复 | minimized-long01 | 实际包313.4秒；不可见期间绘制帧数保持118、资源计数恒85、内存约584.9MiB，恢复后绘制继续，正常退出；峰值618.0MiB |
| OS桌面输入／真人试玩 | 未执行 | 按用户要求不接管屏幕；只用独立非输入桌面真实渲染、模型/引擎输入和审图，不称手动试玩 |

图集静态相位会重置脚锁定，不能替代连续场景。此次没有重绘四套位图或增加贴图尺寸；主网格拓扑不变，头权重是初始化固定数组。PCK从35,334,468增至35,335,284字节，仅增加816字节。

## 资源保护与不接管桌面

所有引擎、导出、发布包运行串行经Start-MemoryBound。游戏仍是1GiB Job硬限、900MiB早停、系统剩余RAM至少2GiB、剩余commit至少512MiB、25%CPU、单实例。默认启动预算仍3328MiB；不因本次测试而给游戏更高额度。

新增有限QA独立桌面通过CreateDesktop和子进程STARTUPINFO.Desktop实现，从不SwitchDesktop，不发送鼠标键盘，不抢用户焦点；子进程退出后关闭桌面句柄。重型运行继续默认预算。已测约115MiB的无窗口几何脚本可用256MiB硬限/224MiB早停；纯蒙皮小窗口脚本可用512MiB/448MiB，必须隔离桌面+有限超时+test-profile，禁止编辑器/导出。冲突诊断配置拒绝启动。重复QA使用Dummy音频或仅静音测试进程的真实WASAPI；均不代表听感验收。

双Rider性能夹具在640×480独立桌面测300帧，关闭夹具的垂直同步后，中位绘制提交约3.00ms/骑手、更新约0.36ms/骑手，帧间隔中位16.67ms。默认垂直同步在非输入桌面出现约45ms帧间隔。此夹具没有完整Battle/UI，不据此承诺游戏60FPS，也不基于非输入桌面的同步表现改玩家设置。未实施透明网格裁剪：当前不是必要修复，跨四种轮廓需要单独像素等价验证；避免在剩余窗口加入未经验证的轮廓变化。

已完成导出峰值613.0MiB；实际对冲含暂存截图峰值738.6MiB，正常退出。日志仍有系统证书读取错误，导出末尾有无权写用户编辑器设置提示；未影响资源打包，未修改系统证书/公司策略。

## 参考与抽象范围

- [University of Kentucky / Extension：Horse Movement and Way of Going](https://horses.extension.org/horse-movement-and-way-of-going/)：足序、体型与运动关系。
- [IFCE：The horse’s natural gaits](https://equipedia.ifce.fr/en/equipedia-the-universe-of-the-horse-ifce/riding/olympic-disciplines/dressage/the-horses-natural-gaits)：步态分类。
- [British Dressage：Walk, trot and canter](https://www.britishdressage.co.uk/our-sport/all-about-dressage/paces-and-movements/basic-paces-walk-trot-and-canter/)：慢步、小跑、跑步节拍。
- [Microsoft：CreateDesktopW](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-createdesktopw)、[Thread Connection to a Desktop](https://learn.microsoft.com/en-us/windows/win32/winstation/thread-connection-to-a-desktop)：后台QA桌面机制。

采用步态节拍和支撑/摆动关系，参数仍为像素游戏的作者曲线和有限关节近似，不是实马运动捕捉或全身动力学。

## 接手者复验

在仓库根目录使用PowerShell。先读保护器输出；预算不足时不移除保护。以下目录名须每次换新，不覆盖原证据。非输入桌面不会出现在用户正在操作的桌面上；结果通过保存的PNG/JSON查看。

```powershell
# 实际发布包：双向、四套马匹的静态相位画面。
./Start-MemoryBound.ps1 -Executable ./builds/LanceAndLaurel-v0.4.21/LanceAndLaurel.exe -IsolatedDesktop -TimeoutSeconds 90 -Arguments '--path E:/GALUMU/builds/LanceAndLaurel-v0.4.21 --audio-driver Dummy --script E:/GALUMU/game/tests/test_horse_gallery060.gd -- --test-profile --gallery=E:/GALUMU/docs/development/logs/feel061-review-new'

# 实际发布包：连续重开，测试进程静音；QA保存位于报告目录。
./Start-MemoryBound.ps1 -Executable ./builds/LanceAndLaurel-v0.4.21/LanceAndLaurel.exe -IsolatedDesktop -TimeoutSeconds 360 -Arguments '--path E:/GALUMU/builds/LanceAndLaurel-v0.4.21 --script E:/GALUMU/game/tests/test_memory_motion061.gd -- --test-profile --scenario=replay-close --steps=300 --interval=1 --window-report=E:/GALUMU/docs/development/logs/feel061-replay-new.jsonl'
```

完整本地原始轨迹／AVI和失败记录保留在工作区；Git只提交专项脚本、精选JSON/内存样本和画面，不把庞大的逐帧轨迹或正式存档入库。发布包在被忽略的builds目录，提交代码不等于发布GitHub Release。

## 最终回执

独立包为`builds/LanceAndLaurel-v0.4.21`，EXE 96,725,504字节，PCK 35,335,284字节，PCK SHA256 `8FE51E9810E3A3B1D8983BD214FED7E6CDA617DDB680A70C8333759FDE59D3EC`。已附保护器、Play-Safe和README；Play-Latest已切换。旧.20 PCK仍为`F3BB63B464964590E5ADD63EA604DDC57D2EF9C50F158AD1A17F217B3DE276E1`。

实际发布包的专项曲线/头骨/固定网格回归同样通过（regression-package01）。本轮所列最终渲染验证峰值最高738.6MiB，来自含暂存截图的完整对冲；长时重开完整日志峰值664.7MiB（中途进度消息曾按当时已读取区间说约642MiB，以完整汇总为准）。没有触发900MiB止损。内存汇总见logs/feel061-final-memory-summary.json，不把这两次五分钟测试等同于所有机器／驱动的长期稳定性保证。

新旧实际包同脚本的16秒并排对照：`docs/development/video/feel061/v0420-v0421-motion-comparison.mp4`，左.20，右.21；两方向、步态转换与催马/松手。固定30FPS离线录制，非OS输入／真人试玩，不能据此推算实机帧率。

正式profile_v1及backup在本轮后段两次校验一致；分别为`C013C4F3FCC7C099DC8AB313C60A70C2AFCF07323CED9A949C718A6304180309`、`546FA357B201A626AB984CA90388262AF3F980176BE238B0BF798A39EB18FF7B`。测试保存均用独立QA路径，不将后段校验冒充开工前校验。

运行修复e8c7d63、隔离桌面保护4acf79e、发布包验证/入口45b8951已本地提交，待最终文档和Git推送SHA核对。本轮未接管屏幕、未改变用户系统音量、未关闭工作软件。已知边界：有限IK和作者曲线仍需玩家主观验收；低速后腿个别变化峰值未降低；Dummy退出警告和系统证书提示按上文保留。
