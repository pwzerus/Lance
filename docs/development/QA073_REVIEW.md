# QA-073：500 MiB 保留线与后台画面复验

2026-11-09，Codex。实际接手 `codex/v0.4` / `18fb3bae53ecda448ce386c3c0a4be53104c55a2`，与已跟踪 origin 引用相同；无新 Claude 生产代码差异。已有 `game/tests/rules_v045_results.json` 和历史未跟踪材料保留、不纳入提交。

## 修改与保护

用户明确允许系统保留约 500 MB 后恢复画面验证。根 `Start-MemoryBound.ps1` 使用 **500 MiB** 可用物理内存停止线（略大于十进制 500 MB），启动日志记录实际保留线和启动预算。其他保护未关闭：普通游戏 1024 MiB Job 硬限、900 MiB 提前停止，渲染诊断 512/448 MiB，几何诊断 256/224 MiB，CPU 25%、低优先级、单实例、提交余量、超时和隔离桌面。

启动预算仍为系统保留线＋子进程额度＋256 MiB 开销，因此普通游戏需 1780 MiB、渲染诊断需 1268 MiB、几何诊断需 1012 MiB 可用 RAM。500 MiB 是运行停止线，不是启动只需 500 MiB，也不能保证别的程序不会在采样间隔内耗尽系统内存。

根 `Play-Latest.cmd` 自动使用新保护器。**旧发布包不覆盖**，包内 `Play-Safe.cmd` 和其保护器仍保留原 1 GiB 系统线；直接 EXE 不经过根保护器。

## 实际验证

所有运行串行经过根保护器、`-IsolatedDesktop`、`-- --test-profile`、`--audio-driver Dummy`。没有切换用户桌面、OS 鼠标键盘输入或真人试玩。外部 QA 脚本由实际 `.29-r3` EXE 执行，未传源码 `--path`，生产脚本与资源从 PCK 加载。完整比赛为无奖励练习场，未写正式存档；QA 路径为 `user://qa_profile_v1.json`/backup。

| 画面与证据目录（均在 logs/） | 复验及人工看图结果 | 范围限制 |
| --- | --- | --- |
| qa073-motion-{bay,black,grey,flaxen}01 | 8 张双向图集，三速度，最终 96 格运动姿势；四套马皮、三种马衣材质、四纹章；未见新的尾腿梳齿、远腿遮挡错误、头身断开 | 按实际步态积分后截帧；trace 含最后一格覆写前采样，共112记录，不等于112独立格；非全动画视频的主观评价 |
| qa073-fit-{eng,fr,de,it}01 | 4 图集，四国六档同档头盔/胸甲、双向、三俯仰，共144格；未见新的头颈或领口断开 | 未遍历任意头盔×胸甲交叉搭配 |
| qa073-hud01 | 100/45/20/0 四档疲劳，文字和条宽均在范围内；耗尽显示实际变化0，速度上限100/100/81/70% | 固定测试窗口，非全DPI |
| qa073-contact1、qa073-contact-1 | 双向6类受击、每类4时刻；盾心受压、上下盾缘扭转及头胸腰落点标记可区分，未见手柄脱离 | 合成事件隔离反应，不能当自然命中率/平衡证据 |
| qa073-match01 | 正常 AI/自动控制完成三轮练习赛，比分2:0，双方存活；冲锋、接近、命中和结算4截图逐张检查，结果文字未覆盖奖励/按钮 | 约42秒比赛，44.5秒进程；不是长期内存测试、OS输入或真人手感验收 |

12 个 report 均 `passed:true`、12 进程退出0，12 隔离桌面 `QA_DESKTOP_CLOSED=True`。本次未复现需要修改生产游戏代码的新缺陷，因此不重复导出已有 PCK。

所有引擎日志仍有已知环境提示 `Can't create shader cache folder ... user://`；本执行环境用户目录不可写，渲染实际完成。未见新的 SCRIPT ERROR、资源泄漏退出警告或保护器提前停止。没有把此环境错误隐去或声称日志完全无错误。

## 内存记录

1秒采样值，单位 MiB；不是瞬时峰值。

| 运行后缀 | 游戏私有内存峰值 | 系统可用 RAM 最低 |
| --- | ---: | ---: |
| motion-bay01 | 358.0 | 1663 |
| motion-black01 | 360.9 | 2196 |
| motion-grey01 | 362.8 | 2208 |
| motion-flaxen01 | 364.8 | 2251 |
| fit-eng01 | 388.4 | 2242 |
| fit-fr01 | 375.0 | 2153 |
| fit-de01 | 383.3 | 2199 |
| fit-it01 | 385.6 | 2207 |
| hud01 | 407.1 | 2216 |
| contact1 | 342.7 | 2263 |
| contact-1 | 339.2 | 2233 |
| match01 | 723.2 | 1777 |

本轮没有故意耗尽内存去触发500 MiB停止线，不能声称该极限场景已经实测。历史40GB问题不因这批短测宣布全部根治。

## 复现命令与包身份

例（PowerShell，项目根）：

```powershell
& ./Start-MemoryBound.ps1 -Executable ./builds/LanceAndLaurel-v0.4.29-r3/LanceAndLaurel.exe -RenderDiagnostics -IsolatedDesktop -TimeoutSeconds 45 -Arguments '--script E:/GALUMU/game/tests/test_visual072.gd --audio-driver Dummy --log-file E:/GALUMU/docs/development/logs/qa073-motion-bay01.log -- --test-profile --suite=motion --selection=bay --folder=E:/GALUMU/docs/development/logs/qa073-motion-bay01' -MemoryLog E:/GALUMU/docs/development/logs/qa073-motion-bay01-memory.txt
```

fit 换 suite=fit、selection=eng/fr/de/it；contact 换 suite=contact、selection=1/-1。HUD 用 `test_hud072.gd`，整局用 `test_match072.gd`，这两项不传 RenderDiagnostics，整局 TimeoutSeconds=110。重跑必须换新输出目录，不能覆盖本次证据。

- 当前 `.29-r3` PCK SHA256：`C5544BF0528CCC92151759194752894CBFC95AAABA82713EBDD012DD5CF017FC`，35,748,172 字节，复验后未变。
- 旧 `.28` PCK SHA256：`D468711A87DF0D7B9D9836A0791FD42F6D2E3DE1C336F4A49156695BAAB9DBC7`，未变。
- 无新的游戏版本或资产导出；本轮提交保护器、记录及证据，builds 不进 Git。
- 待后续：真人确认冲击/震感、声音材质听感、长时间稳定性、任意装备混搭；罩袍纹章仍未实现。马衣纹章已经检查，二者不可混淆。
