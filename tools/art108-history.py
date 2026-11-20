"""Build a compact review from existing item metadata and human-checked pages.
This does not fetch URLs or label an asset historically accurate automatically.
"""
import json
from pathlib import Path

root=Path(__file__).resolve().parents[1]
items=[]
for name in ('en_fr','de_it'):
    items+=json.loads((root/f'game/data/history_v051_{name}.json').read_text(encoding='utf-8'))
notes={
'810947':'欧洲，12世纪末至13世纪初；具体国家未定，不能称英国出土。',
'464233':'约1250年英国骑士棋子，或在伦敦制作。仅作装备图像参考，不是存世钢盔／胸甲。',
'26451':'15世纪晚期法勃艮第式萨莱特，可能意大利；存在严重锈蚀及修复，英格兰线是游戏编排。',
'22741':'1527年格林尼治组合甲；或属亨利八世，不把整套重量当胸甲重量。',
'851637':'1586年格林尼治Clifford组合甲，Jacob Halder主持制造；战地与比武交换部件并存。',
'23205':'约1400–1450及后加部件；1920年代拼配修复，覆绒布为20世纪，不能称完整原套。',
'21988':'约1375–1425，可能法国；圣女贞德归属仅19世纪传说，馆方认为大概不实。',
'21982':'约1475，可能法国或佛兰德；地区保留不确定性。',
'21979':'约1550法国burgonet，宫廷装饰；不把贵族礼物当普通军械。',
'470599':'1248年后至1267年，卢瓦尔河谷石灰岩墓像；织物和内甲组合是据像改编。',
'34331':'约1400意大利内铆板甲，希腊Chalcis发现，覆层为织物；法国线表示采用／进口主题。',
'24671':'约1555法国、可能巴黎的亨利二世甲；装饰与归属保留馆方限定。',
'34323':'约1400德意志面甲盔；皮革为现代，不能全算原物。',
'34258':'1480德意志萨莱特与护颏；分别登记的部件，不是帽沿式开放盔。',
'35922':'约1520及后加部件，纽伦堡；后补腰裙不当原套制造依据。',
'23145':'约1450德意志箱形胸甲；具体购入与出土地未知，方折胸形可用。',
'23143':'约1475–85，德意志或奥地利；不能收窄为已知德国单一工坊。',
'22317':'约1550–55纽伦堡Kunz Lochner胸甲，钢和金；只对应胸甲原件。',
'23239':'约1325–50，可能意大利；原盔曾被剪短并在眼部改切，现轮廓非确定原始状态。',
'23238':'约1350–1400并有后世修复，意大利；石膏修复不能写成历史钢料。',
'27960':'约1460米兰barbute，窄T形开口、单板锻造；此原物没有固定冠饰的孔，不加无来源冠饰。',
'24810':'约1490意大利armet；后脑圆片和杆为修复，原锁甲缘及外加护面已佚。',
'24696':'约1575–80意大利、可能米兰的混合组合甲；头盔用于骑枪赛，胸背甲原为步战部件，骑乘胸甲为明确游戏改编。',
'23144':'约1510–15米兰胸甲，刻蚀古典战利品及宗教横饰；金色带为游戏整理，不称全鎏金原件。',
'1919.63':'约1475–1500北意大利哥特式胸甲与腰裙；哥特式并非德国独占。',
'1921.1250':'约1500–1525侍卫板甲衣，意大利归属带问号；不能据此证明特定法国主人。',
'1916.1804.a':'约1560–70德意志、可能奥格斯堡三脊burgonet，开放面部及铰接颊片。',
'hounskull-bascinet.html':'H21藏品标签1350–1380、西欧；页面类型概说另有1370–1430，不能混用为此件日期。',
'armour-of-the-dauphin.html':'G118约1540，米兰、可能Negroli工坊；法国皇太子订制不是法国制造。',
'158530':'Morgan M.638 fol.23v，巴黎约1244–1254；插画可支持环甲、盾和马衣形制，不能证明隐藏材质。',
'en/':'KHM B74约1330奥地利大盔；Prankh归属有疑问，来自Seckau葬礼陈设，牛角为皮革织物。',
'the-hundred-years-war-1337-1453':'Royal Armouries正文明确IV.600为14世纪中叶英格兰／欧洲大盔；对象页正文未被工具读出，未虚构进一步尺寸。',
'panstereomachia/':'SMG现页Fig.8及正文记述Canterbury黑太子罩衣，1376年死后陈设；不能支持先前Fig.9及精确1360年起点。',
}
groups={}
for item in items:groups.setdefault(item['source_url'],[]).append(item)
lines=['# ART-108 历史出处复核（2026-11-20）','',
'逐件对照当前48件区域头盔／胸甲的元数据。以下“已复核”指已读取馆藏机构、原藏机构或其学术出版物的相关说明；不表示像素素材是考古复原，也不表示完成了原物实测。造型、制造地、角色地区、现代修复和游戏数值分别看待。原V051历史审查存在未提交且读取乱码的内容，原样保留。','',
'## 当轮发现与修正','',
'`eng_armor_2`的来源误写SMG Fig.9，当前页面是Fig.8；改为“Canterbury 黑太子遗物 / SMG Fig.8”。年代改为“14世纪；1376年以前”，撤掉当前资料不能支持的1360年精确下限。既有内层护甲与数值为游戏适配的说明保留。没有改价格、解锁或护甲。机构自己的展览说明也确认藏有该罩衣：[Canterbury展览](https://www.canterbury-cathedral.org/news/posts/major-new-cathedral-exhibition-tells-the-complex-and-violent-history-of-church-state-relations/)。','',
'## 48件对应来源','',
'| 游戏物品ID | 来源 | 当轮复核与限制 |','| --- | --- | --- |']
verified=0
for url,group in groups.items():
    key=url.rstrip('/').split('/')[-1]
    if url.endswith('ironmen.khm.at/en/'):key='en/'
    if url.endswith('panstereomachia/'):key='panstereomachia/'
    note=notes.get(key)
    if note:verified+=len(group)
    elif '/bbb/0120-2/' in url:note='单页图像仍未复核；补读同馆编目说明，确认南意、约1195–1197及132r/133r叙事主题。编目支持年代和语境，不能替代盔甲形制逐图核对。'
    else:note='当轮未完成重新访问：Heidelberg遇访问限制／超时。保留此前有出处且明确图像改编的文字，不将此次当作复核通过。'
    actual=url
    if 'clevelandart.org/art/' in url:actual=url.replace('/art/','/print/art/')
    lines.append('| '+', '.join('`'+x['id']+'`' for x in group)+' | ['+group[0]['source']+']('+actual+') | '+note+' |')
lines+=['',f'合计48件，当前成功核对来源说明覆盖{verified}件；其余{48-verified}件保留“当轮未复核”的证据限制。Cleveland使用馆方打印版条目；Heidelberg限制未绕过。',
'','## 武器、纹章与外观的边界','',
'- 72件地区骑枪是4条地区收藏线×3类×6档的游戏系统，不宣称72种独立出土制式。轻、长、粗杆及分档护手／饰纹可辨，地区之间共享技术符合既有跨区域采用设定。','- [Met的四件比武枪头](https://www.metmuseum.org/art/collection/search/35791)同时包含尖头Scharfrennen与四爪Gestech。竞技场统一三爪、实战叶形枪头是本游戏的辨识规则；不能写成历史上一切比赛必用钝头、一切尖头必属战争。','- 固定盾纹与可换家族纹章属于游戏收藏／角色身份；不冒称全部对应真实家族。家族纹章作用于罩袍、马衣、枪旗，盾纹保持独立。','- 80位对手使用现有自建外观的稳定组合，不是80张新画素材，也不把肤色或脸型绑定为某国的历史判定。闭盔会自然遮住脸，远景不能保证靠面容分辨所有人。','- 装备重量、保护数值、负重与耐力仍是平衡参数；馆藏整套重量不能直接填进单个胸甲或头盔。','',
'## 待后续核对','',
'Heidelberg的Cod. Pal. germ.112及848、Bern Cod.120.II相关单页图像此次仍未完成直接复核；不因检索摘要宣称看过原图。数字图像只作出处核对，没有下载外部图像接入发布包；未增加新的第三方图像许可负担。','',
'## 补充取得的编目证据（不混算单页图像）','',
'[e-codices馆藏编目，Florian Mittenhuber，2018](https://www.e-codices.unifr.ch/en/description/bbb/0120-2/Mittenhuber)已实际读取：Cod.120.II约1195–1197，产地南意、Salerno，亦有Palermo假说；132r为1194年进攻Salerno，133r为Diepold事迹。说明明确这些图像含政治宣传意图。因此可补强三件意大利早期装备的年代／叙事语境，不能把图中人物等同普遍装备标准，也不能仅凭编目确认藏在衣下的环甲。此前6件单页未复核的数字保持；其中3件现在取得这项部分证据。']
out=root/'docs/development/ART108_HISTORY_REVIEW.md'
out.write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('items',len(items),'source_pages',len(groups),'verified_items',verified,'pending',48-verified)
