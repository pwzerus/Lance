# DEV-051：德意志与意大利装备原物核验

负责人：motion_qa。2026-10-30核验。基线7c727b2，版本分支codex/v0.4。交付范围为24条历史覆盖数据与美术结构简报；不修改价格、声望、伤害或防护数值，不运行Godot。旧ID全部保留，`art_id`与ID一致。正文的“德意志”是游戏地区线，含有明确标注的奥地利或德语文化圈参考，不代表现代统一国家。

数据文件：[history_v051_de_it.json](../../game/data/history_v051_de_it.json)。六档是游戏购买品质，不等于六个严密考古年代，更不意味着最高档的敞脸盔比所有闭盔更安全。`helmet_material=steel`为现有玩法材质分组，不用它断言早期图像所画铁器的冶金成分。

## 首要修正与原物边界

本轮读取了Met当前官方collection API，并与网页、原图比较。旧搜索摘要或旧出版物的断代不能自动覆盖最新馆藏判断：

- **04.3.238 / object25393**：当前API为“probably early to mid-19th century in the style of ca.1400”。旧图片与出版物曾列约1400或1420–1430。退出本轮中世纪原物清单，改用真正列为约1400年的29.156.65。
- **04.3.293a–t / object21928**：当前API为“19th century and partially15th century”。退出本轮作为完整15世纪哥特甲的参考，改用29.150.77。
- **29.154.3**：约1400–1450及后期，20世纪由哈尔基斯出土件拼配修复，现代天鹅绒与许多黄铜边饰。没有拿照片上完整外衣当保存完好的中世纪原貌。
- **42.50.27a–n**：不是一套各件同用途的“完美骑枪甲”。盔与臂甲用于骑枪赛，现胸甲没有骑枪架，馆方归足战或步兵；骑乘胸甲显示明确标为游戏改编。

当前官方数据可复核：[04.3.238 API](https://collectionapi.metmuseum.org/public/collection/v1/objects/25393)、[04.3.293 API](https://collectionapi.metmuseum.org/public/collection/v1/objects/21928)、[29.154.3目录](https://www.metmuseum.org/art/collection/search/23205)、[42.50.27目录](https://www.metmuseum.org/art/collection/search/24696)。这是本轮实际发现的目录冲突，不把旧研究记录悄悄改成“从来没有争议”。

## 已选24件与可执行结构差异

下列每个来源的具体原图均已实际目视，原图审计见下节。手稿图像用于形制和时代证据，不是出土实物或测量图。

| ID | 中文名／年代 | 制作与使用的可确认范围 | 美术brief与不能混用的特征 |
| --- | --- | --- | --- |
| de_helmet_0 | 德语区鼻护盔；12世纪末 | Heidelberg Cod.Pal.germ.112 fol.63r，雷根斯堡或黑森—图林根制作地未定；文学叙事里的骑乘战士 | 小圆顶、鼻护、露脸，配锁甲头套；不加后期犬嘴面罩、钢护颈或大号维京角。不认定具体制盔作坊。 |
| de_helmet_1 | 施蒂里亚大盔；约1330 | KHM B74，奥地利；曾置塞考修道院Prankh家族葬礼陈设 | 折面包头、窄水平眼缝、铆接板缝。原物巨大双角为皮革、亚麻、粉底及金银箔；游戏不加角，不能把葬礼皮冠画成钢战角。 |
| de_helmet_2 | 德式长面罩盔；约1400 | Met29.156.65，德国；现代皮革 | 高尖碗、侧枢轴、长前突面罩、眼缝与成列圆呼吸孔；不是额头中央翻板结构。 |
| de_helmet_3 | 哥特式盔与护颏；1480 | Met29.158.6a,b，德国 | 圆滑高盔碗、独立外张护颏，两件间留横视缝；不要把独立护颏并成闭盔一体下脸。 |
| de_helmet_4 | 纽伦堡沟槽闭盔；约1520及后配 | Met49.163.1a–s等，纽伦堡；整套有较晚腰片腿裙 | 圆碗密排纵沟、面罩横折棱、叠护颈；约束沟槽数量以适应像素阅读，不复制整套较晚部件。 |
| de_helmet_5 | 三脊骑兵敞面盔；约1560–1570 | Cleveland1916.1804.a，德国、可能奥格斯堡；类型供骑步兵用 | 三条高齿脊、前盔檐、活动颊片、敞脸。不可加密闭骑枪眼缝；同类见查理五世卫队，不称这件是皇帝亲用。 |
| de_armor_0 | 朴素长身锁甲；12世纪末 | Heidelberg cpg112 fol.41v，德语地区图像；实际制甲作坊未知 | 深灰有组织环链大色块、颈口与下摆，柔性胸体；没有15世纪钢胸板。 |
| de_armor_1 | 纹章罩袍锁甲；约1300–1340图像 | Heidelberg cpg848 fol.17r《马内塞歌集》，苏黎世制作，德语宫廷比武图像 | 清楚的蓝／红或其他原创纹章罩袍色面，腋下颈口露锁甲；布面褶皱，不画成铆钉板甲，勿照抄历史家族纹章当玩家默认身份。 |
| de_armor_2 | 箱式折面胸甲；约1450 | Met29.150.79，德国 | 上胸高直、折面外扩、收腰、短外张下缘，V形放射槽；与后期圆鼓沟槽胸明显区分。 |
| de_armor_3 | 哥特式叠腰胸甲；约1475–1485 | Met29.150.77，德国或奥地利，不细定城市 | 中脊、扇状成束弧槽、修长腰线、横向叠腰片；不借19世纪拼甲补出“原配肩臂”。 |
| de_armor_4 | 纽伦堡沟槽胸甲；约1520及后配 | Met49.163.1a–s等，纽伦堡；两片胸板及镂空装饰并非该时通用标准 | 圆胸密纵沟、分片收腰、右骑枪支撑件；只保留胸体结构，肩臂由现有角色独立连接。 |
| de_armor_5 | 洛赫纳雕饰胸甲；约1550–1555 | Met14.25.866，Kunz Lochner，纽伦堡 | 修长尖腹、中脊，卷草蚀刻分成大组，窄金边和少量金铆钉；不要涂成纯金甲或用蚀刻模糊基本体积。 |
| it_helmet_0 | 南意鼻护盔；约1195–1197图像 | Bern Cod.120.II fol.133r，南意、可能萨莱诺；斯陶芬与当地军队语境 | 小尖圆碗、窄鼻护与露脸；同期军队人员来源多样，不能说是意大利独有民族型。 |
| it_helmet_1 | 分面早期尖顶盔；约1325–1350 | Met29.158.44，**可能**意大利 | 矮尖分面碗、开放面；现存眼上缺口和短下缘是后改，游戏用完整边缘改编，不把缺口变成原装双眼洞。 |
| it_helmet_2 | 深颊尖顶盔；约1350–1400、后修 | Met29.158.43，意大利；含后期修复与石膏 | 高圆尖顶与垂直深颊，宽U状开脸、侧边安装点；现图无面罩，不为了等级加入德式犬嘴。 |
| it_helmet_3 | 米兰T面巴布特盔；约1460 | Met42.50.15，米兰；圣马可狮印可能表示威尼斯军械库或关税管理，解释未定 | 高圆盔碗、小尖脊、深颊、窄T形面口及加强边。看得见脸的区域须保持透明，不能画真人脸。 |
| it_helmet_4 | 米兰式双颊闭盔；约1490 | Met49.163.4，意大利；后脑圆片与杆后修，原锁甲边及wrapper缺失 | 双颊铰接于耳侧并在下巴前合，短尖面罩、加厚眉板、右侧透气孔；不是单一底铰的后期close helmet。名称指风格，不能把未定作坊硬写米兰制造。 |
| it_helmet_5 | 蓝钢金饰闭盔；约1575–1580 | Met42.50.27a–n，意大利、可能米兰；骑枪赛部件，可能德意志公爵客户 | 高脊、细眼缝、叠护颈、蓝灰钢与窄金饰带；客户与制造地区分。 |
| it_armor_0 | 南意朴素锁甲；约1195–1197图像 | Bern Cod.120.II fol.132r／133r，南意图像 | 连环甲胸体、柔性垂落、露颈边；不用布衣人物反推其藏有钢板。 |
| it_armor_1 | 南意覆布锁甲；12世纪末形制改编 | 同手稿fol.132r可见布衣与环甲人员；**覆布+内锁甲组合属于游戏设计** | 朴素赭红／青绿布料大面、领口少量露锁甲；不宣称原图衣内不可见部分确为锁甲，更不称意大利专用制式。 |
| it_armor_2 | 意式板片覆布甲；约1400 | Met29.150.105，意大利；原物内板与残布 | 多排纵向小矩形板在布内铆合；外观只见有节奏铆钉列、布面及衣边。完整衣色为改编，不画裸黑板马甲充当完整原貌。 |
| it_armor_3 | 北意中脊胸甲；约1475–1500 | Cleveland1919.63，北意大利 | 平滑中脊胸体、横叠腰片、黄铜玫瑰铆钉。官方也称Gothic，不把全部意式胸甲强制无棱圆化。 |
| it_armor_4 | 米兰蚀刻胸甲；约1510–1515 | Met29.150.78，米兰 | 圆胸中脊、上胸横向圣徒饰带、中央古典战利品竖带及斜卷草带；原物无镀金痕迹，游戏不涂满黄金。 |
| it_armor_5 | 蓝钢金带组合胸甲；约1575–1580 | Met42.50.27a–n，意大利、可能米兰；现胸甲属足战或步兵用途 | 蓝灰钢大面、修长尖腹、窄金边及中央金饰带。骑乘显示为明确改编；不加不存在的原装骑枪架来掩盖用途差异。 |

## 来源、原图与实际观察审计

临时研究原图均置于`C:/Users/yifei/AppData/Local/Temp/v051_refs/`，仅供内部查图；不把这些照片当游戏素材交付或重分发。下载文件有受控进程读权限差异，因此实际用同一受控Python进程的Pillow解码，并以JPEG预览输出到对话观察；没有根据标题想象原物。9件Met原物还做过`met_sheet01.png`对照。该图是研究对照，不是生成游戏素材。

| 对应ID／馆藏 | 官方目录与具体原图 | 本轮实际观察 |
| --- | --- | --- |
| de_helmet_0 / de_armor_0；cpg112 | [馆方IIIF目录](https://digi.ub.uni-heidelberg.de/diglit/iiif3/cpg112/manifest)；[fol.63r](https://digi.ub.uni-heidelberg.de/iiif/3/cpg112%3A063r.jpg/full/max/0/default.jpg)、[fol.41v](https://digi.ub.uni-heidelberg.de/iiif/3/cpg112%3A041v.jpg/full/max/0/default.jpg) | 已看`roland_63r.jpg`与`roland_41v.jpg`：骑手小型盔与环甲图式。馆方日期是12世纪末，不能把故事年代当抄本年代。 |
| de_armor_1；cpg848 fol.17r | [馆方目录页](https://digi.ub.uni-heidelberg.de/diglit/cpg848/0029)、[原图](https://digi.ub.uni-heidelberg.de/diglitData/image/cpg848/1/017r.jpg)、[IIIF目录](https://digi.ub.uni-heidelberg.de/diglit/iiif3/cpg848/manifest) | 已看`manesse017r.jpg`，标题“Der Herzog von Anhalt”：混战比武、长罩袍、露出环甲与大盔。第一次程序用子串匹配叶码误覆盖为417r，已识别并另存正确017r重看；不使用错误图作为证据。 |
| it_helmet_0 / it_armor_0,1；Bern Cod.120.II | [馆方详细著录](https://www.e-codices.unifr.ch/en/description/bbb/0120-2/Mittenhuber)；[132r原图](https://media.e-codices.ch/iip/bbb/bbb-0120-2/bbb-0120-2_0132r.jp2/full/1000,/0/default.jpg)、[133r原图](https://media.e-codices.ch/iip/bbb/bbb-0120-2/bbb-0120-2_0133r.jp2/full/1000,/0/default.jpg) | 已看`bern132.jpg`、`bern133.jpg`：132r萨莱诺攻城，133rDiepold战事，鼻护盔、环甲和素色布衣。手稿约1195–1197；实际事件有1194等更早日期，不混同制作日期。 |
| de_helmet_1；KHM B74 | [官方展览原物说明](https://ironmen.khm.at/en/)；[原图](https://ironmen.khm.at/fileadmin/user_upload/xHJRK_B_74_201904_01-min.png.pagespeed.ic.i4StMrEnpQ.webp) | 已看`prankh.jpg`：钢盔眼缝、折面与接缝，皮冠巨大双角。图文清楚区别铁主体与皮革亚麻冠饰。 |
| de_helmet_2；Met29.156.65 | [目录](https://www.metmuseum.org/art/collection/search/34323)；[原图](https://images.metmuseum.org/CRDImages/aa/web-large/29.156.65_006june2015.jpg) | 已看`34323.jpg`：高尖碗、突出面罩与整列呼吸孔。 |
| de_helmet_3；Met29.158.6a,b | [目录](https://www.metmuseum.org/art/collection/search/34258)；[原图](https://images.metmuseum.org/CRDImages/aa/web-large/29.158.6a_005june2015.jpg) | 已看`34258.jpg`：独立护颏外张、上盔与护颏分层的水平缝，不把它当整件闭盔。 |
| de_helmet_4 / de_armor_4；Met49.163.1a–s等 | [目录](https://www.metmuseum.org/art/collection/search/35922)；[原图](https://images.metmuseum.org/CRDImages/aa/web-large/DP271145.jpg) | 已看`35922.jpg`：密纵沟、圆胸、面罩横折、骑枪支撑；后配腰腿片不作为同年整套证据。 |
| de_helmet_5；Cleveland1916.1804.a | [目录](https://www.clevelandart.org/art/1916.1804.a)的Image／Expand原图 | 已看`clevelandhelm.jpg`：三个齿状脊、盔檐、敞脸与活动颊。下载的是官网Next图像代理对应的馆方piction原图，非搜索缩略图推测。 |
| de_armor_2；Met29.150.79 | [目录](https://www.metmuseum.org/art/collection/search/23145)；[原图](https://images.metmuseum.org/CRDImages/aa/web-large/DP-12882-026.jpg) | 已看`23145.jpg`：直高上缘、放射槽、收腰与外张下缘。 |
| de_armor_3；Met29.150.77 | [目录](https://www.metmuseum.org/art/collection/search/23143)；[原图](https://images.metmuseum.org/CRDImages/aa/web-large/DP-12882-025.jpg) | 已看`23143.jpg`：成束弧槽、中脊、叠腰。 |
| de_armor_5；Met14.25.866 | [目录](https://www.metmuseum.org/art/collection/search/22317)；[原图](https://images.metmuseum.org/CRDImages/aa/web-large/LC-14_25_866-007.jpg) | 已看`22317.jpg`：卷草大组、长腹、边缘金饰，不是纯金胸甲。 |
| it_helmet_1；Met29.158.44 | [目录](https://www.metmuseum.org/art/collection/search/23239)；[原图](https://images.metmuseum.org/CRDImages/aa/web-large/29.158.44_003dec2014.jpg) | 已看`23239.jpg`：分面尖顶、后改眼部切口。馆方明确说原来更长。 |
| it_helmet_2；Met29.158.43 | [目录](https://www.metmuseum.org/art/collection/search/23238)；[原图](https://images.metmuseum.org/CRDImages/aa/web-large/29.158.43_007AA2015.jpg) | 已看`23238.jpg`：深颊、宽开脸、尖圆碗，无现存面罩。 |
| it_helmet_3；Met42.50.15 | [目录](https://www.metmuseum.org/art/collection/search/27960)；[原图](https://images.metmuseum.org/CRDImages/aa/web-large/DP-12880-047.jpg) | 已看`27960.jpg`：T面开口、加强边、窄鼻部与短后尾。 |
| it_helmet_4；Met49.163.4 | [目录](https://www.metmuseum.org/art/collection/search/24810)；[原图](https://images.metmuseum.org/CRDImages/aa/web-large/49.163.4_005AA2015.jpg) | 已看`24810.jpg`：双颊接缝、眉板、右面孔与短面罩。后修圆片、丢失wrapper依馆方注明。 |
| it_helmet_5 / it_armor_5；Met42.50.27a–n | [目录](https://www.metmuseum.org/art/collection/search/24696)；[原图](https://collectionapi.metmuseum.org/api/collection/v1/iiif/24696/2295959/main-image) | 已看TEMP上一级`v051_met_42_50_27.jpg`：蓝钢、窄金边与竖饰、尖腹、高脊闭盔；组件用途遵馆方说明，不能由完整摆拍推定同用。 |
| it_armor_2；Met29.150.105 | [目录](https://www.metmuseum.org/art/collection/search/34331)；[原图](https://images.metmuseum.org/CRDImages/aa/web-large/DP-12882-018.jpg) | 已看`34331.jpg`：摊开内侧纵排板片与残布；完整外衣为复原。 |
| it_armor_3；Cleveland1919.63 | [目录](https://www.clevelandart.org/art/1919.63)的Image／Expand原图 | 已看`clevelandarmor.jpg`：光滑中脊、收腰和两道明显叠片。 |
| it_armor_4；Met29.150.78 | [目录](https://www.metmuseum.org/art/collection/search/23144)；[原图](https://images.metmuseum.org/CRDImages/aa/web-large/74661.jpg) | 已看`23144.jpg`：圣徒横带、中央竖带及斜向蚀刻，仍有大面积金属面。无镀金证据另据[馆方研究](https://resources.metmuseum.org/resources/metpublications/pdf/Some_Elements_of_Armor_Attributed_to_Niccolo_Silva_The_Metropolitan_Museum_Journal_v.pdf)。 |

Walters51.470、51.584、51.580.1的目录也核验过，但当时直接原图均受403阻挡，本轮最终清单改用已经实看的Met同类可靠原物。不能把“查过Walters标题”写成“看过其原图”。

## 美术实施与验收边界

本表不是24套可随意拼接的同年历史全身复原。可自由购买混搭，但菜单应显示各件年代、归属不确定性、来源和游戏改编。早期两地区采用共享环甲与鼻护类形制，不能为了区分阵营伪造民族独特结构；同款家族可用适度轮廓、罩袍裁剪及原创纹章区分，绝不在早期胸口塞一块后世胸板。

三分之四朝右、胸面部分向镜头、独立头盔与无四肢躯干沿用现有挂点。开放盔脸口必须透明并测量多边形；闭盔不烘焙人脸。头、颈、臂的联接由既有骨架负责，不能在躯干素材多画一条肩臂。用大像素块表达结构，铆钉、蚀刻和环甲只作成组细节，缩至实际尺寸仍先读出鼻护／大盔／长面罩／sallet／沟槽闭盔／三脊burgonet的差异。

本文件的验证仅为官方目录与原图研究。生成是否成功、真实alpha／裁切／脸口、Godot导入、左右骑手显示、抬盾与前后倾均须由后续素材和引擎证据单独报告；没有把研究完成等同游戏内验收。
