"""Publish the DEV-113 receipts into handoff docs, only after the final audit."""
from pathlib import Path
from datetime import datetime, timezone
import json

root = Path('E:/GALUMU')
docs = root / 'docs/development'
s = json.loads((docs / 'DEV113_SUMMARY.json').read_text(encoding='utf-8-sig'))
a = json.loads((docs / 'DEV113_FINAL_AUDIT.json').read_text(encoding='utf-8-sig'))
assert a['passed'] and not a['issues'] and s['formal_save_unchanged']
assert s['campaign_clears'] == 80 and s['soak_processes'] == 8
stamp = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')

def read(name):
    return (root / name).read_text(encoding='utf-8-sig')

def write(name, value):
    (root / name).write_text(value, encoding='utf-8')

def replace_once(text, old, new):
    assert text.count(old) == 1, (old, text.count(old))
    return text.replace(old, new, 1)

metric = (f"实际 c5 完成 80 关首通、{s['campaign_matches']} 场、{s['campaign_purchases']} 次正常购买，"
          f"保留 {len(s['natural_losses'])} 次自然失利。另有八个独立串行进程累计 "
          f"{s['soak_seconds']:.3f} 秒、{s['soak_matches']} 场持续对局；不是一个进程连续 48 分钟。")
perf = (f"八配置平均 {s['soak_minimum_average_fps']:.3f}–{s['soak_maximum_average_fps']:.3f}FPS，"
        f"最长帧 {s['soak_longest_frame_ms']:.3f}ms，{s['soak_frames_over_33ms']} 帧超过 33ms、"
        f"{s['soak_frames_over_50ms']} 帧超过 50ms。私有内存每秒采样峰 {s['soak_private_peak_mib']:.1f}MiB；"
        "不是内核高水位、无限时稳定或所有电脑锁 60 的证明。")
overview = f"""## 当前交付：DEV-113 / v0.4.60-c5（2026-11-24）

REQ-112 与追加的极简 HUD 已完成实现和后台复验。落马改为分部位惯性、接地和关节缓冲；伤情、意识、坐稳、离鞍与死亡分开；可回稳、马上昏厥与后续滑脱；轻盾耐久和可见破损；详细战斗信息默认关闭，在设置或暂停中主动开启。修复靴尖穿地、前伏穿马颈及同一物理步双命中的结算顺序偏差，保留画质、动作精度和有限枪盾移动。

{metric} {perf}

28 项最终包检查、完整成长独立账目/计分/状态复核、10 个便携探针、中文空格路径外层实际 GPU 启动及八个正式存档路径前后核对通过。所有保护与隔离 QA 档保持；无屏幕接管、OS 输入、真人试玩或硬件试听。

Play-Latest.cmd 已指向独立 c5 外层保护入口。运行源码为 4da1e075a125bc92a37663f09f1835eb0f7d5c61；最终文档提交由本段所在 commit 标识，推送后单独核对远程。封包后生产实现未变，旧发布包和失败证据保留。GitHub 保存源码/文档/测试，本地 ZIP 约 68MiB，未上传二进制 Release。

最终证据：docs/development/DEV113_FINAL_AUDIT.json、DEV113_SUMMARY.json、DEV113_FLOW_EVIDENCE.json；需求逐项映射 DEV113_ACCEPTANCE.md；具体文件、参数和复验入口见 docs/collaboration/handoffs/2026-11-23-DEV-113-Codex.md 与 DEV113_RETEST_GUIDE.md。

本轮认领已释放。三份原历史差异仍保留：V051_EXPERIENCE_REVIEW.md、V051_HISTORY_REVIEW.md、game/tests/rules_v045_results.json。后续先核对实际工作区，不覆盖对方成果。剩余：真人动作/难度/声音评价，特写中未落马骑手可能部分出框，旧 94ms 长帧未唯一复现归因，以及第二台 Windows/真实输入/DPI/签名与商店验收。

以下为此前交付历史，不代表当前发布版本。

"""
for name in ('HANDOFF.md', 'docs/collaboration/PROJECT_STATE.md'):
    text = read(name)
    heading = text.split('\n', 1)[0]
    marker = ('## DELIVERY-107–111 已交付：Windows v0.4.59-c1（2026-11-20）' if name == 'HANDOFF.md'
              else '## 最终交付：v0.4.59-c1（2026-11-20 UTC）')
    assert marker in text
    write(name, heading + '\n\n' + overview + text[text.index(marker):])

name = 'docs/collaboration/TASK_BOARD.md'
text = read(name)
text = replace_once(text, '## DEV-113：受创、离鞍动作与极简战斗界面（2026-11-23，Codex，进行中）',
    '## DEV-113：受创、离鞍动作与极简战斗界面（2026-11-23–24，Codex，已完成）')
text = text.replace('\n\n收尾审查追加已修复：',
    f'\n\n最终交出准备完成于 {stamp}：独立 v0.4.60-c5、28 项最终门、完整 80 关与八配置持续检查通过，正式档不变；默认入口已切换。全部 DEV-113 生产、测试、工具、文档与入口认领释放；原三份历史差异保留。详情见 DEV113_FINAL_AUDIT、DEV113_SUMMARY 和本轮交接。\n\n下列认领及“进行中”描述为开发过程，已由上述最终状态覆盖，不再构成文件占用。\n\n收尾审查追加已修复：', 1)
write(name, text)

name = 'docs/collaboration/WORK_LOG.md'
text = read(name)
text = replace_once(text, '# 开发与交接记录\n\n',
    '# 开发与交接记录\n\n' + overview + '## DEV-113 开发过程检查点（历史）\n\n')
marker = '| QA-111 / 2026-11-20 |'
row = (f"| DEV-113 / 2026-11-23–24 | Codex | codex/v0.4，REQ-112 与极简 HUD | 1aa4a2c → 4da1e075 运行包／8a359c1 成长检查点／本交出 commit | 分部位落地、伤情/意识/支撑分离、马上昏厥、轻盾/极简 HUD，修可见靴底及同帧结算 | 28 项包检查、80 关 {s['campaign_matches']} 场、八配置 {s['soak_matches']} 场、正式档不变；[交接](handoffs/2026-11-23-DEV-113-Codex.md) |\n")
assert text.count(marker) == 1
text = text.replace(marker, row + marker, 1)
write(name, text)

name = 'docs/collaboration/handoffs/2026-11-23-DEV-113-Codex.md'
text = read(name)
text = replace_once(text, '- 日期／时区：2026-11-23，America/New_York。', '- 日期／时区：2026-11-23–24，America/New_York。')
text = replace_once(text, '- 当前状态：v0.4.60-c5 已完成20项基础/开局门、完整80关和10项独立启动探针；外层实际GPU及八配置持续验证继续。尚未切默认入口，文件认领未释放。',
    '- 当前状态：v0.4.60-c5 已完成 28 项最终门、完整 80 关、10 项启动探针、外层实际 GPU 和八配置持续验证；正式档不变。默认入口已切换，文件认领已释放。')
text = replace_once(text, '- 最终交出提交：收尾提交后填写；不能把运行源码 SHA 当作含最终证据的交出 SHA。',
    '- 最终交出提交：本次 release(DEV-113) 提交承载最终证据和入口；运行源码为上列 4da1e075，已推送的完整成长检查点为 8a359c1a3b00ac02d88eaad524259ccbb98595a4。提交后以 Git 回执核对最终 SHA，不将运行源码冒称最终文档提交。')
text = replace_once(text, '中文空格迁移包9文件、10个便携探针通过；外层实际GPU60秒进行中。',
    '中文空格迁移包 9 文件、10 个便携探针、外层实际 GPU 60 秒通过；保护进程正常退出并关闭隔离桌面。')
text = replace_once(text, '| 持续配置与正式档 | 正在运行，最终收据完成后追加。 | 不预填通过。 |',
    f'| 持续配置与正式档 | {metric} 八个正式档路径存在状态与散列不变。 | DEV113_FLOW_EVIDENCE、DEV113_FINAL_AUDIT、DEV113_SUMMARY、DEV113_SAVE_AFTER。 |')
text = replace_once(text, '正式档基线为 DEV113_SAVE_BEFORE.json，收尾后只读核对实际八个路径状态。',
    '正式档基线 DEV113_SAVE_BEFORE.json 与收尾只读 DEV113_SAVE_AFTER.json 完全一致（八个路径，两个既存文件、六个不存在）。')
text = replace_once(text, '- 当前 Play-Latest 仍指 .59-c1，待持续运行及最终档案核对通过后再切换。',
    '- Play-Latest 已指向 v0.4.60-c5 最外层保护启动器；runtime 不作为推荐入口。')
text = replace_once(text, '2. 旧 94ms 卡顿未唯一复现或归因，仍有少量长帧。保留追踪，不宣称已根治或所有电脑锁 60。',
    f'2. {perf} 旧 94ms 卡顿未唯一复现或归因，保留追踪，不宣称根治。')
text = replace_once(text, '5. 当前仍占用 DEV-113 认领文件；最后验证、交出和推送后释放。Claude 接手先核对实际工作区，不覆盖三份历史差异。',
    '5. DEV-113 文件认领已释放。Claude 接手先核对实际工作区与远程，不覆盖三份历史差异。')
text = replace_once(text, '待最终交出后由实际接收者填写分支/SHA、所读证据、实际复验与新问题；不预填 Claude 的接受结果。',
    '由下一位实际接收者填写分支/SHA、所读证据、实际复验与新问题；本栏未预填 Claude 的接受结果。')
write(name, text)

name = 'docs/development/DEV113_ACCEPTANCE.md'
text = read(name)
text = replace_once(text, '基础包复验已完成，完整80关及八组持续配置仍在进行；最终完成状态以交接与 DEV113_FINAL_AUDIT 为准。',
    '28 项最终包检查、完整 80 关及八组持续配置已通过；正式档前后不变。实际结果见交接、DEV113_FINAL_AUDIT 与 DEV113_SUMMARY。')
text = replace_once(text, 'c3 第 56 关自然发生生命仍有 15.373 的昏厥，是另有记录的实际成长证据。',
    '实际 c5 第 56 关自然发生生命仍有 15.237 的昏厥，是另有记录的实际成长证据。')
write(name, text)

name = 'docs/development/DEV113_RETEST_GUIDE.md'
text = read(name)
text = replace_once(text, '默认入口待最终持续运行和正式档核对结束后切换；以最终交接为准。',
    '默认入口已在最终持续运行和正式档核对通过后切换。')
text = replace_once(text, '当前进度和最终是否通过以交接与最终审计为准。',
    '全部通过，逐项结果见最终交接、DEV113_FINAL_AUDIT 与 DEV113_SUMMARY。')
write(name, text)

name = 'docs/development/DEV113_REVIEW.md'
text = read(name)
text += f"\n### c5 最终交出核对（{stamp}）\n\n{metric}\n\n{perf}\n\n28 项最终门、原包/迁移包清单与 ZIP 散列、10 个启动探针、外层实际 GPU、完整成长账目/状态及八个正式档路径全部通过。24 次专项结果重开最长同步开局 {s['maximum_synchronous_start_ms']:.3f}ms、最长结果帧 {s['maximum_result_frame_ms']:.3f}ms。封包后生产实现无差异，Play-Latest 切为 c5。原失败、主动故障注入及历史候选均保留，未接管屏幕、未进行真人/硬件声音验收。\n"
write(name, text)

name = 'README.md'
text = read(name)
marker = '## 开始游戏'
assert marker in text
intro = f"""# 骑枪与桂冠 · Lance & Laurel

Godot 4.5.1 + GDScript 的 Windows 单机骑枪游戏，当前分支为 `codex/v0.4`，独立试玩版为 **v0.4.60-c5**，尚未上架商店。启动方式见下文；具体改动和边界见 [交接入口](HANDOFF.md) 与 [DEV-113 审查](docs/development/DEV113_REVIEW.md)。

本版改善落马的分部位惯性、关节缓冲和接地过程，区分受伤、昏厥、失衡落马与实战阵亡；轻盾更容易因重击破损。战斗界面默认简洁，详细状态需在设置或暂停中开启。修复靴尖穿地、前伏穿马颈和同时命中的结算顺序偏差，保留原画质与有限枪盾移动。

{metric} 最终包检查和正式档核对通过，详见 [证据摘要](docs/development/DEV113_SUMMARY.json)。{perf} 后台验证不能代替真人动作、难度和听感评价。

"""
text = intro + text[text.index(marker):]
text = replace_once(text, 'builds/LanceAndLaurel-v0.4.59-c1-Windows.zip', 'builds/LanceAndLaurel-v0.4.60-c5-Windows.zip')
write(name, text)

name = 'docs/development/DEV113_PACKAGE_C5.json'
meta = json.loads(read(name))
meta['crc_and_manifest_relocation'] = 'Passed; final candidate audit, full campaign and eight sustained configurations passed.'
meta['final_audit'] = 'docs/development/DEV113_FINAL_AUDIT.json'
write(name, json.dumps(meta, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'documents_updated': True, 'time': stamp, 'candidate': s['candidate']}, ensure_ascii=False))
