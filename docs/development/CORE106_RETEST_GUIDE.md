# CORE-106 恢复完整后台验证的顺序

本记录是待执行步骤，不是通过回执。当前源码检查点ac8cbfb05183cd540ee3a740af9ed04ed2070700，实际接手还须核对HEAD和未提交差异；正式入口仍v0.4.57-c3。用户最后指示“先做轻量检查，稍后再验证”，未收到恢复指示前不启动下列完整画面工作。

1. 用户恢复后先检查启动预算。完整游戏/导出经Start-MemoryBound原1024MiB配置，系统预留500MiB、启动可用1780MiB和其他保护保持；GPU加-IsolatedDesktop。串行、隔离QA，独立新日志目录，不接管屏幕。AppData shader cache受限错误须与游戏错误区分，不在错误日志上宣称干净通过。
2. 先跑`test_pennon_time106.gd --folder=<新目录>`：固定姿态、墙上时间过去而游戏时钟不走时旗饰像素应相同；游戏时钟推进应变化，双向均覆盖。随后`test_motion105.gd --folder=<新目录> --coats=bay,black,flaxen,grey --kinds=ride,lean,fatigue`及连续`test_charge_motion_v056.gd`，实际观察起步/松手/再催马、马背和骑手节奏、远腿、疲劳叠加与接缝。各旧脚本参数以实际源码为准。
3. 真实落马/镜头使用`test_scene104.gd`，非KO受击使用`test_mounted_contact105.gd`；观察旗饰/脱手接续、马与栅栏遮挡、盾心/擦边和头胸身体反应。必要时增加已有fall_fuzz105的截图子集，不把合成姿态当成自然比赛结果。检查两方向、枪盾有限速度和暂停恢复。
4. 最新`profile_result099.gd --trace099 --folder=<新目录> --seconds=240 --mode=war --difficulty=2 --kit=english_late --blood --no-slow --fullscreen`测真实Main/Battle/结算重开。新interval_hot包含上一显示间隔，不再被物理先行重置丢弃；horse_skin/rider_pose/rider_draw存在嵌套，不能相加当总CPU。记录接触/落马分段P99和>33/>50ms，不能只报平均FPS。原94ms未复现仍保留未定位。
5. 在实际流程/动作通过后更新版本到独立候选目录，导出Windows，再跑实包库存、正常前关/中期对局、结果保存重开、音量开关、隐藏恢复及外层保护入口。核对正式档前后散列、PCK/包散列，旧发布包不覆盖；通过后才更新Play-Latest、最终交接和GitHub推送回执。

轻量检查已完成的证据见CORE106_REVIEW/EVIDENCE，针对无新变化且已通过的项目无需重复耗时。现存48组胸甲像素对照、早期4分钟实际重甲基准，不能替代后续改动的上述验证。没有OS输入、真人试玩或硬件听感时明确写未执行。
