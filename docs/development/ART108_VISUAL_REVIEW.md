# ART-108 原始画面复核

范围：隔离桌面的实际GPU输出，由Codex查看原始图片；不是OS鼠标键盘、真人试玩或主观体验盲测。数字报告仅检查配置／有限值／挂点等。没有通过重新缩放、修图或画外遮盖制造通过截图。以下路径均相对`docs/development/logs/`；原图保留本地。

## 已观察

| 证据 | 观察与边界 |
| --- | --- |
| art108-fit-baseline01/screens/fit-{eng,fr,de,it}.png | 24套同档头盔胸甲，双向、前倾/直立/后仰。原有登记未见明显空隙；闭盔保留内衬和护颈，不以露出完整脸为标准。 |
| art108-identities01/screens/identity-0-1.png、identity-0--1.png、identity-1--1.png、identity-2-1.png、identity-3--1.png | 同一开放头盔下覆盖80对手面容的一侧，另补第一页镜像。肤色、脸轮廓、胡须有变化；不声称远景中每个身份都一眼可分。 |
| art108-mixed01/screens/mixed-{fr_helmet_0,it_helmet_0,de_helmet_4,eng_helmet_3,fr_helmet_4,it_helmet_3}.png | 四种胸甲混搭、双向、三俯仰。已查开放盔、鼻盔、闭盔与T形开口；额前及下巴遮挡符合盔的开口，颈根仍在领口中。全矩阵576帧的有限值检查不等于全部24图已人工逐张审美通过。 |
| art108-faces01/screens/faces-fr_helmet_4-1.png、faces-it_helmet_3--1.png、faces-eng_helmet_3--1.png、faces-de_helmet_5-1.png | 六肤色与四脸型。低护面遮眼和T形窄开口为素材特征，不扩大护面只为露出五官。 |
| art108-lances01/screens/（英实战整枪、意竞技整枪、德实战断枪） | 三类杆形、护手及饰带可区分；竞技冠头和实战尖头不同，断枪没有悬空保留枪尖／旗饰。地区共用欧洲形制，不能把变体数量说成考古制式数量。 |
| art108-cloth01/screens/（linen右向、velvet左向） | 12家族纹章对应罩袍、马衣和枪旗，固定盾纹保持；四马皮轮换，远腿未被错误镜像到同侧。比较图枪远端可能裁出，不算全武器构图验收。 |
| art108-character01/screens/character_saved_reopened.png | 保存重开后的脸型与骑乘预览相符，肖像仍为代码像素绘制；测试装备因合法收藏校验回退，不把夹具指定装备留存当已验证。 |
| art108-shields01/screens/（24盾总览）及art108-heraldry01/screens/family-armory-bottom.png、camp-crest_chevron.png | 盾形、固定图案及边框有区别。家族末页卡片真实加载；换家族后盾仍独立。 |
| art108-wardrobe02/screens/item-helm_nasal.png | 实际营地预览合法旧头盔，与新资料片装备共存。242次切换的节点及缓存检查另列主审查。 |
| art108-campaign01/screens/level1-hit.png、level2-hit.png、level6-hit.png | 实际双方对冲中的新玩家/敌方脸、头盔、领口和马匹。第6关近景盾心反馈存在；首个接触抓帧并不能证明整段慢动作节奏合格。 |
| art108-campaign01/screens/level7-result.png | 结果显示竞技场按分判胜却不列比分，明确交UX-110修复；不能仅凭伤害条理解胜负。 |

## 正在补查

补充查看`art108-campaign02/screens/level10-hit.png`、`level15-hit.png`：冠军开放盔与首次实战闭盔/马衣组合正常，玩家与对手装备不同；盾心滑开和盾心挡住的文字来自真实接触记录。

已看`art108-falleng01/screens/fall-eng-0.png`、`art108-fallfr01/screens/fall-fr-4.png`、`art108-fallde01/screens/fall-de-3.png`、`art108-fallit01/screens/fall-it-5.png`：同一衣甲从离鞍到卧地，头颈与两臂没有突然更换／消失，左右和三区域受力姿势有差别。每图的镜头重新居中且不画已脱手长枪；不将其当实际摄影机或脱手物理证据。

已看`art108-motion01/screens/bay_ride1.png`与`grey_fatigue-1.png`：加速与收速对应不同肢体伸展、重心和头颈姿态，疲劳恢复后控制回稳；不同马皮与远侧腿保持贴合。六张采样不能独自证明全程流畅，持续对局仍由独立场景检查覆盖。

补充查看`art108-mixed01/screens/mixed-eng_helmet_5.png`及`art108-faces01/screens/faces-de_helmet_0--1.png`：雕饰闭盔混搭的后仰护颈保持连接；德鼻盔左向六肤色四轮廓没有额外皮肤从护颈外漏出。远景下细微瞳色不易分辨属像素尺寸限制，不扩大五官制造夸张表情。

已看`art108-campaign03/screens/level20-hit.png`、`level21-hit.png`、`art108-campaign04/screens/level25-hit.png`、`level27-hit.png`：实际配装头颈保持，近景双方跑道与马体遮挡分层正常；25关胸部接触明确，头盔视野遮罩属于现有受击反馈，不误记成贴图缺失。首个接触的单帧不代替整段落马摄影机检查。

继续补查80关实际配置和自建外观的逐批对局；落马后的区域受击、双向、极端姿势及不同头盔的连续帧。只有实际完成并看过的项目才加入上述表格，不以预定范围写成完成。

已看`art108-campaign05/screens/level33-fall0-step0.png`、`step2.png`、`step3.png`（实际文件名均带level33-fall0-前缀）：离鞍时仍在原挂点，随后胸部后仰、腿离鞍、下落保持同一面容／盔甲。摄影机跟随并淡化遮挡马体、栅栏；约0.7秒对手躯干与玩家部分重叠，头盔和下落方向仍可见，不能描述成完全无遮挡。没有看到模型突然散件或头颈消失。

## 不作过度结论

混搭图补充逐张检查：英0/1/2/4、法1/2/3/5、德0/1/2/3/5、意1/2/4/5，共17张，连同此前7张已看完mixed01的24张原始图。每张包含四胸甲、双向和三俯仰。鼻盔的颊侧和锁甲领、桶盔下缘、狗面盔护颈、沙拉盔及金色闭盔在该采样范围没有新增裸露间隙或皮肤透出金属；开放意大利盔的下颌仍落在护颈之上。盾和长枪挡住部分脸属于真实姿态遮挡，不能当头部缺失，也不据此把被遮处当已看清。旧图最下方标题有局部裁剪，已知是测试标注层级，生产UI不受影响。

当前脸型是既有代码像素素材的组合扩展，没有生成80张新位图。本阶段没有改碰撞、伤害、AI、动作频率或资源分辨率。主观自然程度仍需玩家反馈；此复核不代表商业发行认证、所有显示器或所有窗口设置已通过。

实际关卡42追加观察：`art108-campaign06/screens/level42-fall0-step1.png`与`step4.png`，从胸部受击到1.208秒落地同一银色开放盔、白色甲衣保留。落地时前景玩家腿部遮挡部分对手躯干，脸和倒地方向仍可辨；前景马匹透明但骑手始终实体。属于已观察的部分重叠，不写作完全无遮挡。第43关结果再次确认缺少比分与奖励数额，已列UX阶段。
