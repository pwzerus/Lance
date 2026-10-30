# DEV-051 英格兰／法兰西装备形制研究与实装映射

日期：2026-10-30 UTC。研究人：Codex motion_review。读取现有 `game/data/equipment_expansion.json` 后建立 **24 条 override**：每地区 6 头盔 + 6 躯干防护。实际 ID 为 `eng/fr_helmet/armor_0..5`；“第1～6档”对应 quality 0～5，不创建新 ID。同步文件为 [history_v051_en_fr.json](../../game/data/history_v051_en_fr.json)。

## 使用边界与可靠度

- 商店地区表示玩家的收藏线，不能自动等同制造地。法国王室会向米兰订甲，英格兰亦有大陆式样；没有具体佩戴记录的进口主题，必须明确是游戏分配，不能改写为该文物曾在该国使用。
- 每个下面的方案都查了具体馆藏／手稿页；对应的实际图像已在本轮工具会话查看。远程图只入内存观察，没有复制为游戏纹理。图像权利并不由历史事实的可用性自动推导，生成素材仍须独立绘制。
- 早期躯干以锁甲、罩袍和绗缝衣为主，不把 1100–1300 画成钢胸板。**quality 是旧有奖励数值，不是“年代越晚或越封闭必定越安全”的史学结论。** era 仅用于既有 0～4 解锁桶；部分近边界物件或高品质物件不会机械地一档对应一百年。
- 数据覆盖只提供名称、时间、来源、制造／用途、art_id 和材质分类。不得覆盖旧 price、renown、收藏 ID 或数值 stats。材质字符串 `steel` 在引擎中是铁／钢接触音的统一分类，**H21 馆签仍写锻铁**，不把它改称已证实的现代钢材。
- 一件原组合甲含头盔和躯干，可分别作为两件游戏素材的来源；这不是把一件文物虚报为两件不同原物。游戏不会复原整个 garniture 的全部换装关系。
- **未加入**腿伤、马伤、刀剑、拔刀玩法、运动甲声。腿甲若另做只属装饰；本表不提高对应护甲值。

## 英格兰：6 个头盔

| 保留 ID | 名称／年代，era | 精确来源与制造／使用区别 | 可见结构 brief（已看原图） |
| --- | --- | --- | --- |
| `eng_helmet_0` | 英格兰 · 欧洲式鼻铁盔；12世纪末–13世纪初；0 | [Met L.2018.48.13](https://www.metmuseum.org/art/collection/search/810947)。欧洲；具体工坊未定。西欧鼻铁盔结构参考；不证明此原物曾在英格兰使用。 | 开放式盔碗与独立鼻铁保留清晰轮廓；未遮住两颊。 [馆方小图（仅观察，不作图像输入）](https://collectionapi.metmuseum.org/api/collection/v1/iiif/810947/1907790/restricted) |
| `eng_helmet_1` | 英格兰 · 平顶包面大盔；约1250；0 | [Met 17.190.231](https://www.metmuseum.org/art/collection/search/464233)。棋子可能伦敦制作；所示钢盔工坊不详。同期英国骑士装备图证；不复制棋子的人脸与象牙材质。 | 平顶筒状包面盔，窄视缝与硬直前脸明显区别鼻铁盔。 [官方图](https://images.metmuseum.org/CRDImages/md/web-large/DP277659.jpg) |
| `eng_helmet_2` | 英格兰 · 尖顶铆接大盔；14世纪中叶；1 | [Royal Armouries IV.600](https://royalarmouries.org/objects-and-stories/stories/the-hundred-years-war-1337-1453)。英格兰／欧洲；工坊未定。百年战争早期骑兵防护结构参考；后期大盔与比武的联系增强。 | 高尖盔顶、中央脊与分段铆缝；单侧呼吸孔形成不对称前脸。 [官方图](https://royalarmouries.org/sites/default/files/styles/1_1_media_small/public/2025-01/DI%202011-0246.jpg.webp?h=8a7fc05e&itok=UxOysT3p) |
| `eng_helmet_3` | 英格兰 · 尖脊短尾萨莱特；15世纪晚期；3 | [Met 29.150.13](https://www.metmuseum.org/art/collection/search/26451)。可能意大利；法勃艮第式样。英格兰线的大陆式样改编；馆方提及英格兰教堂保存的同类。 | 后倾尖脊盔碗、分离额片和短外撇颈尾；保留前方开口。 [官方图](https://images.metmuseum.org/CRDImages/aa/web-large/DP22352.jpg) |
| `eng_helmet_4` | 英格兰 · 格林尼治圆喙闭盔；铭年1527；3 | [Met 19.131.1a–r,t–w,.2a–f,l](https://www.metmuseum.org/art/collection/search/22741)。英格兰格林尼治王家工坊。有战场及比武换装件的组合甲；可能曾作为赠予法国使节的礼物。 | 圆凸盔碗、较钝的封闭面甲与成组呼吸孔；颈缘封合。 [官方图](https://images.metmuseum.org/CRDImages/aa/web-large/DT753.jpg) |
| `eng_helmet_5` | 英格兰 · 伊丽莎白式尖喙闭盔；1586；4 | [Met 32.130.6a–y;36.98.1](https://www.metmuseum.org/art/collection/search/851637)。英格兰格林尼治；Jacob Halder主持。George Clifford的战场／比武组合甲；非所有附加件同时装用。 | 高脊与尖突面甲配合叠片颈圈；金饰集中为大块带纹。 [官方图](https://images.metmuseum.org/CRDImages/aa/web-large/DT259974.jpg) |

## 英格兰：6 个躯干防护

| 保留 ID | 名称／年代，era／材质 | 精确来源与用途 | 可见结构 brief（已看原图） |
| --- | --- | --- | --- |
| `eng_armor_0` | 英格兰 · 共通式锁甲衫；约1244–1254图证；1100–1300主题；0／mail | [Morgan MS M.638 f.23v](https://ica.themorgan.org/manuscript/page/46/158530)。图像：巴黎；实际锁甲产地未定。圣经故事中的13世纪装备图证，不是早期圣经时代军服。 | 露出整片链环胸身与柔软腰部，领缘承接锁甲兜，不画钢胸板。 [f.23v 原图](https://ica.themorgan.org/icaimages/6/m638.023v.jpg) |
| `eng_armor_1` | 英格兰 · 无袖罩袍锁甲；约1250；0／mail | [Met 17.190.231](https://www.metmuseum.org/art/collection/search/464233)。棋子可能伦敦制作；所示防具工坊不详。英国骑士图像；不是仅把上一件锁甲换色。 | 无袖长罩袍覆盖链环，宽松胸腹、骑乘开衩与系腰形成新轮廓。 [官方图](https://images.metmuseum.org/CRDImages/md/web-large/DP277659.jpg) |
| `eng_armor_2` | 英格兰 · 绗缝纹章短罩衣；约1360–1376；1376前遗物；1／padded | [Canterbury 01107 / SMG Fig.9](https://journal.sciencemuseum.ac.uk/article/panstereomachia/)。英格兰关联遗物；具体制作者未定。Canterbury黑太子遗物；不是单独钢甲，展示图中的复制品须区别。 | 合体短腰身、前襟系结与竖向绗缝；纹章分区按大色块整理。 [原遗物档案照 Fig.9 左上](https://journal.sciencemuseum.ac.uk/wp-content/uploads/sites/14/2020/05/figure-9-compox3-square-768x896.jpg) |
| `eng_armor_3` | 英格兰 · 大陆式双片覆布甲；约1400–1450；现陈列含后配；2／brigandine | [Met 29.154.3](https://www.metmuseum.org/art/collection/search/23205)。意大利；Chalcis出土零件；1920年代组合。展示早期大胸片与小铆片结合；不声称本件曾由英格兰人穿用。 | 两块大胸片支撑合体躯干，中心三道横扣、金属包边与短下摆。 [官方图](https://images.metmuseum.org/CRDImages/aa/web-large/DP-46028-001.jpg) |
| `eng_armor_4` | 英格兰 · 格林尼治圆腹胸甲；铭年1527；3／plate | [Met 19.131.1a–r,t–w,.2a–f,l](https://www.metmuseum.org/art/collection/search/22741)。英格兰格林尼治王家工坊。可能亨利八世的战场／比武组合甲；原始所有人仍保留可能性。 | 圆凸胸腹、紧腰、卷起颈臂缘和横叠腰甲；保留右侧枪托接口。 [官方图](https://images.metmuseum.org/CRDImages/aa/web-large/DT753.jpg) |
| `eng_armor_5` | 英格兰 · 克利福德尖腹组合甲；1586；4／plate | [Met 32.130.6a–y;36.98.1](https://www.metmuseum.org/art/collection/search/851637)。英格兰格林尼治；Jacob Halder主持。英格兰宫廷骑士的战场／比武组合甲；游戏未复原整套附件。 | 向下尖突腹甲、明显窄腰与曲瓣腰裙；大纵带金饰强调金属体积。 [官方图](https://images.metmuseum.org/CRDImages/aa/web-large/DT259974.jpg) |

## 法兰西：6 个头盔

| 保留 ID | 名称／年代，era | 精确来源与制造／使用区别 | 可见结构 brief（已看原图） |
| --- | --- | --- | --- |
| `fr_helmet_0` | 法兰西 · 宽檐铁帽；约1244–1254；0 | [Morgan MS M.638 f.23v](https://ica.themorgan.org/manuscript/page/46/158530)。图像绘于巴黎；所示铁帽工坊未定。13世纪法国图像中的战斗装备；外檐尺寸作像素可读性调整。 | 低圆盔碗配四周外伸檐，脸部开放；轮廓区别鼻铁盔。 [f.23v 原图](https://ica.themorgan.org/icaimages/6/m638.023v.jpg) |
| `fr_helmet_1` | 法兰西 · 平顶包面盔；约1244–1254；0 | [Morgan MS M.638 f.23v](https://ica.themorgan.org/manuscript/page/46/158530)。图像绘于巴黎；所示钢盔工坊未定。法国13世纪图证；绘画为结构来源，不是存世整盔的测绘。 | 低平盔顶、硬直包面片、成对眼孔和前脸铆带；颈部仍接锁甲。 [f.23v 原图](https://ica.themorgan.org/icaimages/6/m638.023v.jpg) |
| `fr_helmet_2` | 法兰西 · 尖吻巴西内盔；约1350–1380（具体馆签）；1 | [Musée de l’Armée H21](https://www.musee-armee.fr/en/collections/museum-treasures/hounskull-bascinet.html)。西欧；工坊未知；锻铁。晚14世纪头部防护结构；无已知具体法国佩戴者归属。 | 长尖吻面甲、细眼缝、侧轴铰链和后斜高尖盔碗，锁甲连接孔清楚。 [官方图](https://www.musee-armee.fr/fileadmin/_processed_/c/7/csm_Bacinet_a_bec_de_passereau_e80b0ac0d6.jpg) |
| `fr_helmet_3` | 法兰西 · 高尖开放巴西内盔；约1375–1425；选取1400前后造型；2 | [Met 04.3.241](https://www.metmuseum.org/art/collection/search/21988)。可能法国；工坊未定。可能有战斗损伤；游戏以开放面陈列轮廓改编，品质不代表开面更安全。 | 高尖后倾盔碗、大拱面部开口、下沿连接铆孔；保留暗色锻铁感。 [官方图](https://images.metmuseum.org/CRDImages/aa/web-large/DT11527.jpg) |
| `fr_helmet_4` | 法兰西 · 短尾覆面萨莱特；约1475；3 | [Met 04.3.227](https://www.metmuseum.org/art/collection/search/21982)。可能法国或佛兰德；工坊未定。15世纪头盔；不混成德式超长尾或后世莫里昂盔。 | 圆滑盔碗、短后尾、低长视缝与前翻檐缘，整体低而宽。 [官方图](https://images.metmuseum.org/CRDImages/aa/web-large/DP101947.jpg) |
| `fr_helmet_5` | 法兰西 · 浮雕梳冠勃艮第盔；约1550；4 | [Met 04.3.217](https://www.metmuseum.org/art/collection/search/21979)。法国；装饰与枫丹白露宫廷艺术关联。宫廷豪华头盔；可拆护面配件不与各时代头盔随意混装。 | 高弧梳冠、上翘长前檐、独立颊片和颈缘；圆章浮雕采用大块明暗。 [官方图](https://images.metmuseum.org/CRDImages/aa/web-large/DP273710.jpg) |

## 法兰西：6 个躯干防护

| 保留 ID | 名称／年代，era／材质 | 精确来源与用途 | 可见结构 brief（已看原图） |
| --- | --- | --- | --- |
| `fr_armor_0` | 法兰西 · 外露长身锁甲；约1244–1254；0／mail | [Morgan MS M.638 f.23v](https://ica.themorgan.org/manuscript/page/46/158530)。图像绘于巴黎；所示锁甲工坊未定。13世纪人物图像；不是古代以色列的装备复原。 | 连续链环覆盖胸腹，宽颈口与腰带压褶；无需画成刻满线条的胸板。 [f.23v 原图](https://ica.themorgan.org/icaimages/6/m638.023v.jpg) |
| `fr_armor_1` | 法兰西 · 垂褶罩袍锁甲；1248之后–1267之前；0／mail | [Met 25.120.201](https://www.metmuseum.org/art/collection/search/470599)。法国卢瓦尔河谷石雕；所示防具工坊不明。d’Aluye家族骑士纪念像；身份具体归属亦有讨论。 | 无袖罩袍宽开肩口、胸腹纵褶和系带收腰；领缘露出锁甲。 [官方图](https://images.metmuseum.org/CRDImages/cl/web-large/DP365741.jpg) |
| `fr_armor_2` | 法兰西 · 层叠大铆片衣甲；约1400（解锁段边界）；1／brigandine | [Met 29.150.105](https://www.metmuseum.org/art/collection/search/34331)。意大利；在Chalcis堡垒遗存中发现。躯干铆片防护；不把外露考古残片当成原始外表面。 | 布面内覆宽大长方铆片，肩口收窄、腰腹横排；稀疏铆列提示结构。 [官方图](https://images.metmuseum.org/CRDImages/aa/web-large/DP-12882-018.jpg) |
| `fr_armor_3` | 法兰西 · 意式细铆绒甲；约1500–1525；3／brigandine | [Cleveland 1921.1250](https://www.clevelandart.org/art/1921.1250)。可能意大利；具体工坊未知。骑士及步兵皆可用的brigandine形制；本例采用金绒豪华面层。 | 小铆片密集网格、圆领、侧系绳与波瓣下摆；软硬层次区别整块胸板。 [官方原图](https://www.clevelandart.org/_next/image?q=75&url=https%3A%2F%2Fpiction.clevelandart.org%2Fcma%2Fump.di%3Fe%3DB3F3533B1DAF9F1C9743856CE368183060D2AD3A9228DF87ED25FA6411F15C58%26s%3D24247294%26se%3D116628280%26v%3D1%26f%3D%5Cd9941%5Cu228099412%5C1921.1250_o5.jpg&w=640) |
| `fr_armor_4` | 法兰西 · 王太子嵌银战甲；约1540；制作约1536–1547；4／plate | [Musée de l’Armée G118](https://www.musee-armee.fr/en/collections/museum-treasures/armour-of-the-dauphin.html)。米兰；可能Filippo与Francesco Negroli。未来亨利二世的军用护甲；游戏不复制整套甲和所有宫廷徽记。 | 较长圆腹、窄腰与叠片腰裙；黑银纵带、对称海豚与弦月只留大纹样。 [官方图](https://www.musee-armee.fr/fileadmin/_processed_/4/3/csm_Armure_du_dauphin_en_entier_9cdb7a0799.jpg) |
| `fr_armor_5` | 法兰西 · 王室浮雕仪仗甲；约1555；4／plate | [Met 39.121a–n](https://www.metmuseum.org/art/collection/search/24671)。法国，可能巴黎；多位设计者参与。亨利二世仪仗甲的装饰主题，不宣传为已经复原的实战骑枪专用甲。 | 微凸胸腹、窄腰、长分片腰裙；中心浮雕大章与暗金卷草形成分区。 [官方图](https://images.metmuseum.org/CRDImages/aa/web-large/DP256970.jpg) |

## 不能省略的逐件改编说明

- `eng_helmet_0`：欧洲共通形制；馆方未定具体产地，英格兰收藏线为游戏编排，银线简化。
- `eng_helmet_1`：原物是约1250年英国骑士棋子，不是实存钢盔；钢制结构与孔位为据图改编。
- `eng_helmet_2`：馆方称英格兰／欧洲；不把大盔所有时期都称比武专用，也不虚构原佩戴者。
- `eng_helmet_3`：可能意大利制造的法勃艮第风格；在英有同类，不证明此件为英制；原物修补甚多。
- `eng_helmet_4`：现归属为可能为亨利八世制作；旧称热努亚克甲不能当法国制造证据。
- `eng_helmet_5`：据克利福德组合甲改编；都铎玫瑰、百合与双E属特定人物和宫廷，不是全国制服。
- `eng_armor_0`：图证绘于巴黎；此处采用西欧共通锁甲结构，英格兰配装和轮廓整理为游戏改编。
- `eng_armor_1`：棋子提供罩袍覆锁甲的图证；衣料颜色、玩家纹章和内层细节为游戏改编。
- `eng_armor_2`：黑太子原物是覆在金属甲外的绗缝罩衣；本件保留防护槽，内层和数值为游戏适配。
- `eng_armor_3`：原物为意大利组合甲，20世纪重组且天鹅绒为现代；英格兰线进口式样为游戏改编。
- `eng_armor_4`：原组合甲有不同战斗与比武附件；不把所有加固件合成同一实战套装，数值仍为游戏值。
- `eng_armor_5`：深蓝原色现呈褐色；恢复蓝金效果是有依据的设计解释，不把每条小金线照搬进像素。
- `fr_helmet_0`：巴黎画本中的当代装备形制；非法国独有，移入骑枪玩法不等于严格比武安全复原。
- `fr_helmet_1`：同页不同人物并非同一种民族制服；颜色和呼吸孔排列按可读性改编，不编造专属制式。
- `fr_helmet_2`：馆签产地西欧，不写法国制造；尖吻别称是后世分类，页面概论年代不替代具体标签。
- `fr_helmet_3`：馆方仅称可能法国，贞德归属传奇大概不实；原物缺面甲，不臆造为确证完整配件。
- `fr_helmet_4`：可能法国或佛兰德；短尾形制并非法国专利，游戏重新整理铆孔，不复制腐蚀斑。
- `fr_helmet_5`：馆方称法国，可能为亨利二世制作，后赠美第奇；外交流转不改变制造地，不当普通军用制式。
- `fr_armor_0`：巴黎图证中的锁甲为欧洲共通形制；与英格兰线的比例、领缘处理是游戏造型分配。
- `fr_armor_1`：原物是卢瓦尔河谷骑士墓像而非铠甲，原色不能由现石色确定；不搬用其特殊剑。
- `fr_armor_2`：原物意大利制、希腊Chalcis出土，非法国产；加入法兰西线是共通形制改编，布面为补全。
- `fr_armor_3`：馆方仅定可能意大利；法国线进口主题为游戏编排，不证明本件曾在法国使用或原色等同现色。
- `fr_armor_4`：米兰制造、法国王太子亨利关联；馆方认为用于军事，不把意大利工坊误称法国制造。
- `fr_armor_5`：法国可能巴黎制造的仪仗甲；在骑枪中使用、强度数值与简化浮雕均属明确游戏改编。

## 易误认之处与本次取舍

1. **鼻铁盔 L.2018.48.13 是借展私藏，馆方仅定欧洲。** 本轮仅观看馆方限制下载的公开显示小图，确认尖圆碗与 T 形外扩鼻铁；不将图送作生成参考或拷入项目，不宣称英格兰制造。国家线归属是游戏收藏主题。
2. **英国棋子 17.190.231 不是象牙盔甲。** 其硬直平顶包面轮廓可作约1250的图证。[Met馆方装备解说](https://www.metmuseum.org/exhibitions/listings/2011/the-game-of-kings-medieval-ivory-chessmen-from-the-isle-of-lewis/exhibition-blog/game-of-kings/blog/armed-to-the-teeth)亦明确讨论其锁甲、罩袍和骑乘装备；不把雕塑材料带入钢盔，也不据磨损小雕刻编造孔洞测量。
3. **Morgan MS M.638 f.23v** 绘于巴黎约1244–1254，表现旧约故事却使用当代法国装备。页面上可辨宽檐帽、平顶包面头盔、链环兜与罩袍。英格兰裸露锁甲采用共通形制而非“法国画本证明该原物英格兰制造”。主站本轮遇403，改由馆方官方旧图录 `ica.themorgan.org` 读取具体页及原图；不是凭第三方复刻图推断。
4. **IV.600** 馆方称 English/European、14世纪中叶；原图确有尖顶、左右不对称呼吸孔和中央脊。馆方对大盔发展的一般叙述不等于该实物一定平顶或一定只用于比赛。[原馆说明](https://royalarmouries.org/objects-and-stories/stories/the-hundred-years-war-1337-1453)。
5. **H21 具体馆签约1350–1380，产地西欧，锻铁。** 同页科普段落谈此类盔普遍1370–1430，不能用概论抹掉特定物件的标签。最终映射为 `fr_helmet_2`；Met 04.3.241 是 `fr_helmet_3`。早先沟通里的2/3初拟次序以此最终表和JSON为准。
6. **04.3.241 不是已证实的贞德头盔。** 馆方认为19世纪才可追溯的传奇大概不真；面甲现未保存，造型保留开放口，不补出“贞德专属”机关。[馆藏记录](https://www.metmuseum.org/art/collection/search/21988)。
7. **29.150.13 是可能意制的法勃艮第式萨莱特，并且重修过。** 英格兰教堂有相似形式，不代表该件是英制或该件的使用地就是英格兰。与法国04.3.227的低圆碗、覆面长缝作结构区别；不靠换漆制造两国差异。
8. **黑太子罩衣不是钢胸甲。** 编号01107见[Textile Research Centre的原物说明](https://www.trcleiden.trc-leiden.nl/trc-needles/individual-textiles-and-textile-types/commemorative-and-commissioned-textiles/jupon-of-the-black-prince)，并引V&A展览目录65号；本轮没有声称读完该印本。实际看的是Science Museum Group Journal Fig.9中原遗物档案照，能见短袖残段、竖绗缝和前开襟。现代悬挂复制品与墓像无袖样式不能代替原物。游戏独立躯干分件不带整只手臂，护甲槽下的内层防护属于适配。[Historic England BB70/07877](https://historicengland.org.uk/images-books/photos/item/BB70/07877)是1880–1930摄影档案，不能将其照片日期当作罩衣制作年；该站本轮图像服务不可用。
9. **29.150.105 与29.154.3均非英法原产文物。** 前者约1400、意大利、Chalcis出土，原图是内侧裸片，游戏不能把考古残片当原本外表；后者是1920年代用Chalcis零件组合的甲，红绒为20世纪。两大胸半片+扣带，与小片层叠在像素轮廓上分开。[105记录](https://www.metmuseum.org/art/collection/search/34331)、[组合甲记录](https://www.metmuseum.org/art/collection/search/23205)。
10. **Cleveland1921.1250是可能意大利约1500–1525，不是法国制造的铁证。** 本轮看过官方图：圆领、小片密铆格、侧系绳与波瓣边清楚；把它作为法国收藏线的意式绒甲是游戏编排，不杜撰具体法国拥有者。原图现有颜色也不能自动等于新制颜色。
11. **1527格林尼治组合甲现称“Probably Henry VIII”。** 不沿用旧书“Galiot de Genouilhac”直接标为法国甲。制造地格林尼治与可能赠法使节是两件不同的事；不在UI省略“可能”。本项目只取圆腹、卷缘、枪托与横裙，不把战场和各种比武加固件全装一起。[当前馆录](https://www.metmuseum.org/art/collection/search/22741)。
12. **Clifford1586馆号用32.130.6a–y;36.98.1。** 不沿用某些旧教育PDF出现的31.230.6等转写误差。蓝色现已转褐，恢复蓝金是馆方解说支持的解释。图案简化保持大块纵带，不以堆金点代替peascod尖腹与腰裙结构。[现行馆录](https://www.metmuseum.org/art/collection/search/851637)。
13. **G118是米兰制造，法国王太子使用关联。** 原馆具体条目约1540，并解释1536–1547区间；黑银横纵分区与对向海豚可借鉴，不把Milan写成巴黎。[官方记录](https://www.musee-armee.fr/en/collections/museum-treasures/armour-of-the-dauphin.html)。
14. **39.121a–n是约1555法国可能巴黎的仪仗甲。** 其密卷草、人像浮雕是宫廷展示，不证明是骑枪对冲实用甲；游戏允许作为奖励外观用于对冲，是明确适配。[现行馆录](https://www.metmuseum.org/art/collection/search/24671)。
15. **04.3.217 勃艮第盔的制造地和外交流转不能合并。** 法国制作、可能亨利二世、后入美第奇；保留梳冠、檐、颊片，不能只画成另一款全封闭尖喙盔。装饰圆章改为少量像素团块。[当前馆录](https://www.metmuseum.org/art/collection/search/21979)。

## 美术可操作规格

- 使用当前已验证英格兰最高两件的像素色簇与光源，统一四分之三朝镜头、朝右的基准构图。**形制从历史参考取，比例与枢轴从本项目母版取。** 原物侧面照不直接旋转充当三分之四前视图。
- 头盔一件一图，透明背景，无真人脸、无肩膀、无头发填充；开面处作为实际透空，用户像素脸由游戏渲染。
- 躯干一件一图，透明背景，无臂、手、头盔、腿。保留颈口、左右肩口、完整腰缘；原罩衣袖段交给独立臂连接，不能抹掉肩部承接。
- q0–1 不随意添加镀金、都铎玫瑰或法国王室百合。早期差异主要来自开放／封闭头型、外露锁甲／罩袍、长短与褶皱；国色只作为次级识别。
- q2–3 利用大铆片与细铆片、扣带与系绳、绗缝与金属卷缘的差异，禁止同一胸甲仅换色交差。尤其 `eng_armor_3` 的三条横扣/大胸半片，区别于 `fr_armor_3` 的密格铆钉与波瓣边。
- q4–5 保留有结构意义的宽金饰带、少量大徽章、片缝，删去在目标缩放下只会闪烁的细碎金线；不把仪仗浮雕说成额外规则防护。
- 实装仍需双向、盾高低、前后仰和落马的实际引擎渲染。此文研究完成不表示图片已经生成、拆件可用或游戏内已验收。

## 本轮观察记录

实际看过：Met Nasal L.2018.48.13公开限制显示小图；17.190.231；29.150.13；19.131.1；32.130.6；04.3.241；04.3.227；04.3.217；25.120.201；29.150.105；29.154.3；39.121；RA IV.600；Army H21、G118；Cleveland1921.1250；MorganM.638 f23v；SMG Fig9原罩衣档案照。参考图未写入仓库。

额外排除／不作为最终资产依据：国家档案馆DL10/42（1189骑乘印蜕）已看但头部磨损，不能据此画出确定鼻铁细节；St Mary Warwick原教堂图本轮403，另看过Richard Beauchamp墓像公开现场照片和V&A7456墓铭拓片，后者是ca1850–1870拓制、原铭ca1401–1407且属于另一位Thomas Beauchamp，故没有误作为Richard的原甲资料。BM1852,1201.1鼻盔馆录现定可能19世纪伪作，已排除。

