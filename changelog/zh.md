### 7.6.0 (17-11-2026)
**Features**:
- Incyclist、Tour du Pain 和 Rampida 现已通过 OpenBikeControl 获得官方支持。
- CYCPLUS T7 变速拨杆可作为控制器使用：全部八个按键，默认用后方箭头键转向。
- OpenBikeControl 应用现在可以实时看到你的虚拟挡位。
- 更清晰的按键编辑器：操作按用途分组（挡位、骑行台、训练、骑行……），在手机上以底部面板打开。
- Shimano Di2：第三种设置方式——按照分步指南，自己在 E-TUBE 中设置 D-Fly 通道。
- Zwift Click V2：你可以选择不解锁就使用右侧控制器。
- 更多试用空间：试用期内每天 120 次按键（之前 80 次），试用期后每天 40 次（之前 15 次）；没有 Pro 时，BikeControl 自带的虚拟变速每天可用 30 分钟（之前 20 分钟）。

**Fixes**:
- Elite 骑行台不再重复显示（WiFi 和蓝牙）。
- Windows：BikeControl 关闭时不再崩溃，也不会因网络、通知或蓝牙错误而崩溃。
- Android：Android 重启后台服务时不再崩溃，“关闭并退出”总能退出应用。
- Shimano Di2：当拨杆不接受设置时，通道设置会正常结束。

### 7.5.0 (09-11-2026)
**Features**:
- BikeControl 现已支持 Linux（.deb 和 AppImage）。
- 更多骑行训练应用现已通过 OpenBikeControl 获得官方支持：Grimpa、icTrainer、Auuki、VoxVelo、VeloWorkout、Pedalparty、VeloPopuli、Vieta、DirtWatts、WattLog.pro、REZVIVO、OpenRadlr 和 zwoTrainer。
- 在 Zwift 中支持更多操作。
- Power Lock：按一下即可锁定你此刻的功率，无论路况如何变化。停止踩踏时会自动松开，让你不必顶着一堵阻力墙重新起步。
- Shimano Di2：可在 E-TUBE 通道（推荐：即使 BikeControl 断开，Di2 也不会因拨杆而变速）和按键模式之间选择。有线拨杆现在也能使用。
- 现在可以控制早于 FTMS 的旧款骑行台，例如旧固件的 Saris Hammer 和旧款 Wahoo KICKR。

**Fixes**:
- Windows：连接手机的蓝牙桥接重新能发送数据，也不再崩溃。如果训练应用卡在旧的蓝牙连接上，BikeControl 会提示你重新配对。
- Android：长时间骑行后掉线的控制器能再次被找到。
- 你移除的手柄在重启后保持移除状态。
- TrainingPeaks Virtual：控制器连接后不再一直转圈，两部 iPhone 也不再互相冲突。
- 在踏频读数较慢的骑行台上（如 Decathlon D500）减速时，Target Power 不再突然变得很重。
- 虚拟速度会计入你的前牙盘。
- Windows 浮窗会以你保存的透明度和位置打开。
- Shimano 曲柄功率计被正确识别为功率计。

### 7.4.0 (29-10-2026)
**Features**:
- 骑行台上的链条：设置你真实链条所在的牙盘和飞轮，每个虚拟挡位都会像对应的真实挡位一样。
- 随心 ERG：从上次的目标或当前功率开始，步长可选 1、5、10 或 25 W。
- Ride Cave 和 Velotoss 现已通过 OpenBikeControl 获得官方支持。
- 换挡时手柄会震动。
- MUOV 智能单车按键（测试版），以及在新款骑行台上更好的虚拟变速。

**Fixes**:
- Shimano Di2：在按键模式下，握把按键和卫星按键可以使用。
- “仅本次”断开的控制器会保持断开。
- 可识别 Magene PES-P 功率计。

### 7.3.0 (19-10-2026)
**Features**:
- Shimano Di2：集成大幅改进。拨杆可立即作为 BikeControl 按键使用，无需先在 E-Tube 应用中分配 D-Fly 通道。BikeControl 断开后 Di2 恢复正常变速，且不会更改任何 Di2 设置。
- Biketerra 现已获得官方支持：通过 OpenBikeControl 经蓝牙连接 BikeControl，支持按键和转向。
- Stages SB20：单车的变速按键可作为控制器使用（测试版）。

**Fixes**:
- 训练应用处于前台时手柄仍可正常使用（Android、macOS、Windows）。
- 在不确认挡位就直接应用的骑行台上（KICKR 系列、Tacx Neo）改进了虚拟变速。
- 现在可以检测到 Van Rysel 骑行台。
