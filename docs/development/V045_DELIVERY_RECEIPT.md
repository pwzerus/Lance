# DEV-045 最终交付回执

2026-10-28（America/New_York），本轮一小时时限内停止功能扩展并完成验包。运行代码冻结于 **dc09976572d68f375f873d18a09e4a0c47500d37**；完整交接/证据提交 **49a600f0527927b4b1bb55a6583ec8c42fb58506** 已推送origin/codex/v0.4并用ls-remote逐字核对。此回执为后续纯文档提交，未改运行代码或PCK。

## 包身份与归档

- 最终试玩：builds/LanceAndLaurel-v0.4.5-r3/LanceAndLaurel.exe；Play-Latest已指向该包。
- PCK SHA256：D223D4D4216331CDF512A316D5B3EDA483B876A6ACB1D1115EC51FE251F860D9
- Windows ZIP SHA256：2B04D0BB9F43DA5D02C8EB08159847C8A947BD5E3578F2F5EB8374CF4FCE0DF7
- 源码ZIP SHA256：7A895E721CA215B1AB06E74678E4699FC3C8951D0CE6EA9FE5A56C06EF4A7E9E
- 源码ZIP取自提交49a600f0527927b4b1bb55a6583ec8c42fb58506；本回执及后续归档验证日志晚于ZIP，运行代码相同。
- 两种ZIP CRC均通过；系统Expand-Archive解压Windows包后motion通过，解压PCK与原包相同；源码在全新目录干净导入Godot4.5.1并通过motion。
- v0.4.4旧PCK仍为056CD1EE4EA6F1229D8EE630945BA5E1C6FBDDEBD2051B4230A260574740A93E；本轮首包v0.4.5、r2和所有旧发布保留，没有覆盖。

## 实际验证范围

最终r3 EXE的motion、support_rider、transitions、integration、rules五项exit0。十马/双向/30与120Hz变速40组，锁脚、骨长、步序连续性和卷蹄检查通过。竞技场/实战各三轮、结算及九图完成，日志release-r3-smoke.log有SMOKE_TEST_COMPLETE。最终包360帧/30FPS/12秒动作预览已输出；是离线程序观察，不是实时性能或真人录像。

OS仅源QA窗口一次约23ms拖动的按下/抬起到达；真实持续长按与新版真人手感没有验收。旧满血追头落马平衡、像素分件接缝/旋转边缘及结果后台动画更新仍保留，不用测试数证明动作自然。

## 解压兼容性观察

第一次Python解压后，Python仍读到正常项目文本，而.NET和Godot看到8192字节TSD头封装，导致项目配置解析失败。ZIP条目本身是正常UTF-8且CRC有效；同一ZIP用系统Expand-Archive在新目录解压后，Godot干净导入与动作测试通过。这与本机透明加密的跨程序读取差异相符；未识别具体软件/策略，未改安全设置。两个验包目录与失败记录保留；本机源码展开推荐采用已验证的系统标准方式。

详见archive-native-validation.json、archive-source-native-import.log、archive-source-native-motion.log、archive-Windows-native-motion.log。原Python解压目录不是开发主项目。

## 接手

工作目录仍E:/GALUMU/game，按PROJECT_STATE与DEV-045交接；不要在builds验包副本改游戏。本轮文件已释放。Claude既有未提交差异保留；GitHub分支只含源码/文档/选定证据，不含被忽略的builds二进制。下一步先真人观察最终包四档/加减速/双向与重整片段，再按具体异常帧改善。
