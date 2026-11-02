# DEV-056 视频证据

- `motion-comparison.mp4`：左为旧v0.4.15-r2实际包，右为新候选源码。相同test_charge_motion_v056、固定60步、各720帧/12秒；上下两行分别左右朝向。包括巡航、按住催马、松开、俯仰换盾。不同版本步频不同，因此同一秒不一定同一步相。无音轨。
- `full-charge-package.mp4`：实际v0.4.16 EXE/PCK的正常Main/Battle过程，test_full_charge_v056仅经viewport派发按住/松开/再按住和有限枪盾指令；保留正常练习AI、满血、4400初始间距。不是OS输入。MovieMaker固定60帧录制740帧/12.333秒，夹具实际墙钟16.510秒、整个录制进程约21秒；**不能据此测真实帧率或把电影时轴当作真实演出耗时**。正常时钟的独立对照报告为full-charge-package02（12.109秒），fast30和steady-off另列。

完整对冲录制的进程Master音量降低60dB以避免自动QA打扰桌面，MP4转码时仅反向恢复60dB；AAC解码后测得峰值约-6.0dBFS。这里没有人工耳听或真人打击感验收。混音削波检查使用另存的AudioEffectRecord WAV，而不以有损MP4作为精确PCM依据。

原始`baseline.avi`、`candidate.avi`、`full-charge-package.avi`只保留在本机本目录，不纳入Git；转码MP4及生成日志/JSON纳入本轮证据。源码、参数与限制见`V056_REVIEW.md`及三个独立review。
