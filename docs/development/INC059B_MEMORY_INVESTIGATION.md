# INC-059B：内存故障继续定位与移动游戏预算

2026-11-03；Codex；接手2491ad9，codex/v0.4。状态：调查进行中，未认定根因，未发布新游戏包。

## 新证据与上一轮遗漏

系统事件2004的进程创建时间给出了此前没有核对的时间窗口，见logs/inc059b/events.json：

| 事件UTC | 从进程创建起 | 游戏私有承诺内存 |
| --- | ---: | ---: |
| 14:42:10 | 111.22秒 | 39,778,885,632字节 |
| 14:44:08（同一进程） | 229.25秒 | 40,761,319,424字节 |
| 19:56:23（另一进程） | 179.28秒 | 40,331,833,344字节 |

这台电脑物理RAM为16,597,598,208字节（约15.46 GiB）。事故时系统提交量接近60.22GB、提交上限约60.34GB，说明40GB并非游戏持有40GB物理RAM，而是把RAM/分页支持的提交额度耗尽；仍然是严重故障。事件不能说明具体哪个函数分配了内存，也不能推断增长从第111秒才开始。

上一轮82–90秒检查不能覆盖上述事件时间窗口；短时稳定不应被用来排除延迟触发。新夹具默认240秒，之后需要更长往返测试。

## 静态排查结论

- 桌面观察夹具只记录输入与状态，未每帧保存截图；不能把该夹具认定为图像堆积来源。
- 马体网格构建仅在初始化；update只更新固定长度顶点数组。Godot 4.5.1 GLES3实现调用glBufferSubData更新既有缓冲区，不在该函数中创建新网格。这不排除驱动/队列问题，但没有依据把马体代码直接重写成所谓修复。
  来源：https://raw.githubusercontent.com/godotengine/godot/4.5.1-stable/drivers/gles3/storage/mesh_storage.cpp （489–501行）。
- 项目F11走普通WINDOW_MODE_FULLSCREEN，不是EXCLUSIVE_FULLSCREEN；上游#114903的专属全屏病例不能直接套用。
- 菜单字体没有动画FontVariation参数；#95427是可对照的缓存问题，尚不构成本项目归因。
- 声音合成长度有固定上限、共享流，声部池最多12；静态检查未发现菜单按秒无限追加PCM。
- 可能的渲染后端、UI自动化/辅助功能、字体、实际窗口状态交互均需隔离复现。关联不是证据；未确认DLP或Intel驱动责任。

## 已增加诊断能力（不是泄漏修复声明）

Start-MemoryBound.ps1新增-InspectOnly只读系统可用RAM/提交余量；-MemoryMap在受保护子进程运行时周期记录私有/映射/镜像已提交地址区间总量及最大私有区间，不读取内存内容、不生成GB级转储。超过850MiB时加密采样，原1GiB上限和900MiB早停保持。

新tests/test_memory_isolation_inc059.gd提供full、bare、freeze-rider、without-rider、without-ui对照；默认240秒，逐行刷盘，记录引擎节点/资源/纹理/缓冲区计数与实际渲染帧，不在内存保存整个采样历史。

验证：C#编译和只读自身VirtualQueryEx采样已执行；示例进程私有提交61.6MiB，映射132.4MiB、镜像200.7MiB。这些地址区间统计不能当作物理RAM或直接与PrivateMemorySize64相加。新Godot夹具尚未执行/解析验收。

## 为什么现在不能继续运行

只读检查系统可用RAM约3173–3296MiB，低于已经建立的4096MiB启动保留线。保护器未放宽，未启动游戏或编辑器，未替用户关闭任何工作程序。已请求用户在方便时释放内存；有足够余量后，按以下顺序继续：

1. 原版EXE+原桌面观察脚本，在1GiB Job内240秒，记录MemoryMap；无需鼠标输入。
2. 同等窗口下原版/修订版full对照，确认差异，不拿不同档位帧率伪装改善。
3. 根据计数与地址区间增长选择bare、freeze-rider、without-rider、without-ui；区分脚本对象、渲染资源与未被引擎统计的提交增长。
4. 复现后固定唯一变量修复，执行相同触发步骤前后对照；最后导出新目录并复验。直到出现证据前不声称根因修复。

## 小型手机游戏参考：预算不等于系统终止线

- Android小游戏Zombie Base: Tower Defense TD的开发者于2025-11-02公开复盘：初始约250MB，目标小于200MB，优化后报告130–150MB；主要处理图集、未用纹理、重复加载与GUI绘制。这是具体开发者自报结果，未独立测量，且统计口径不一定等同Windows私有提交。
  https://forum.defold.com/t/zombie-base-tower-defense-td-optimization-journey-draw-calls-and-memory/81874
- Defold官方建议根据实际工作集优化资源/组件容量；其58MB→64MB示例是HTML5堆预算，不是Android/iOS所有游戏通用上限。
  https://defold.com/manuals/optimization-memory/
- Android官方App memory budgets文档用256MB演示常驻预算，明确是开发者声明及回收机制；该功能从Android17 QPR2/API37.2起，不能套用全部旧设备，更不是小游戏统一硬上限。GPU资源还可能在该堆预算之外。
  https://developer.android.com/topic/performance/memory/app-memory-budgets
- Apple明确应测量memory footprint（包括脏页/压缩页和统一内存GPU资源）；设备上限随设备变化。没有可直接宣称的“所有iPhone小游戏统一512MB”。
  https://developer.apple.com/videos/play/wwdc2022/10106/
  https://developer.apple.com/documentation/xcode/reducing-your-app-s-memory-use
- Google Play公布的2027年2月起P90质量门槛按设备RAM和前后台不同；例如4GB设备前台游戏2.25GB。这是未来平台质量门槛，不是建议本游戏用到2.25GB，更不是小游戏实际占用调查。
  https://support.google.com/googleplay/android-developer/answer/17492799?hl=en

## 本项目目标（工程决定，未全部达标）

| 平台/阶段 | 正常工作目标 | 峰值目标 | 判断口径 |
| --- | ---: | ---: | --- |
| 当前Windows修复版 | <=512MiB | <=768MiB | 同一机器最终EXE私有提交；同时观察工作集/GPU/引擎资源 |
| 未来移动端 | 暂定<=256MiB | 暂定<=384MiB | Android与iOS各用本平台真实footprint；需真机验证后调整 |
| 当前事故保护 | 900MiB提前停止 | 1024MiB系统Job拒绝新提交 | 防失控，不是正常占用目标；GPU内核/其他应用不在Job内 |

最后一轮Windows末值625.9MiB，因此常驻512MiB目标尚未达到。移动端未导出/真机测试，不把Windows测量换算成手机实测。继续优先去掉未使用资源、控制缓存寿命和场景释放；降低正常内存和修复异常增长都要做，二者不能互相替代。
