# CORE-106 骑乘护甲声音

由 game/tools/build_movement_audio106.py 自制的短声音，没有采样其他游戏或第三方录音。用于游戏表现，不是历史声学测量或真实甲胄录音。

- plate：少量短促的甲片搭接声；mail：细碎环片声；brigandine：更短、更闷的铆片声。每类3个确定性变体。
- 44.1kHz / 单声道 / 16位PCM，每个0.17–0.20秒，样本峰值不超过0.30。骑乘音量低于撞击，随马背压缩回弹强度变化，撞击阶段让位。
- 原始SHA256/时长/峰值/RMS见manifest.json。生成命令：`python -S game/tools/build_movement_audio106.py`。
- 没有新增外部素材许可义务。随项目发布使用；不声称与实物音色完全一致，最终听感仍需真人确认。
