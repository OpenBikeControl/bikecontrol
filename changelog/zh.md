### 7.7.0 (24-11-2026)
**Features**:
- (Pro) 现在可以选择 Wahoo App 作为骑行软件：在安卓设备或 Windows 电脑上运行 BikeControl，它会在 Wahoo App 中作为蓝牙智能骑行台出现，并负责虚拟变速。
- (Pro) Android 搭配仅支持蓝牙的训练应用（如 Grimpa）：骑行页和设置流程现在会提供档位悬浮窗。该应用运行在另一台设备上，你可以用手机做其他事，同时仍能看到档位。

**Fixes**:
- (Base) Android：点击 BikeControl 通知中的“关闭”现在也会移除档位悬浮窗。此前 BikeControl 退出后悬浮窗仍留在屏幕上。
- (Base) 安卓上使用 FulGaz 或 Biketerra：连接骑行台时，BikeControl 现在会请求以骑行台身份出现所需的蓝牙权限。此前桥接会一直转圈，应用也始终看不到它。骑行台页面还会显示应用中列出的名称（安卓会缩短它，例如“KICKR CORE 1234 - Bik”）。
- (Base) iPhone / iPad：BikeControl 现在在后台等待训练应用时会保持运行（最长 15 分钟），并在应用断开后继续保持 5 分钟。以前 iOS 可能在 MyWhoosh 等应用找到 BikeControl 之前就让它休眠，导致应用找不到或无法连接。
- (Base) iPhone / iPad：如果 iOS 仍然让 BikeControl 休眠，回到 BikeControl 后它会自动重新出现在网络上。以前需要重启网络方式。
- (Base) iPhone / iPad：切换 Wi-Fi 或热点后，BikeControl 会立即跟随，而不是继续广播旧地址。
- (Base) iPhone / iPad：搜索 Wi-Fi 骑行台不再让日志充满“App crashed”条目。
- (Base) iPhone、iPad 和 Mac：当网络上找不到 BikeControl 时，主屏幕会提示你，并可一键打开网络检查。
- (Base) Mac：Mac 从睡眠中唤醒后，无需重启网络方式即可再次找到 BikeControl。
- (Base) 另一台设备上的 MyWhoosh：如果一分半钟后仍未通过网络连接，主屏幕现在会提供改用蓝牙的选项。以前只有网络检查页面才有这个选项。
- (Base) 同一台 Android 设备上的 MyWhoosh：主屏幕现在会说明虚拟变速在该设备上无法连接到 MyWhoosh 以及哪些搭配可行，而不是一直等待 MyWhoosh 找到它永远不会列出的骑行台。
- (Base) 另一台 Android 设备上的 MyWhoosh：主屏幕上的骑行台步骤现在会提示把骑行台切换为蓝牙，因为 Android 版 MyWhoosh 只能通过蓝牙找到骑行台。
- (Base) 没有 Wi-Fi 的 Android 手机且训练应用在同一部手机上：现在建议连接任意 Wi-Fi 或使用本地方式，而不是“与应用相同的 Wi-Fi”。
- (Base) 登录后处于离线状态不再让日志充满“App crashed”条目。
- (Base) 网络检查：当 BikeControl 自己正在搜索网络时，或你只使用骑行台桥接并关闭了控制器连接时，不再报告失败。

### 7.6.2 (23-11-2026)
**Features**:
- (Base) Zwift Play / Zwift Ride 拨片：向内拨和向外拨现在是两个独立的按键，可分别设置各自的操作。原有的拨片设置会同时应用到两者。
- (Base) Elite Rizer 和 Sterzo：现在可以在设备页面设置转向死区。
- (Base) 配件操作（例如 Rizer 的坡度增加 / 减少）现在可以直接在配件页面分配到已连接控制器的按键上：在控制器图片上点按按键，再选择单击、双击或长按。

**Fixes**:
- (Base) Windows：用控制器按键截取的截图现在会以正确的颜色包含整个屏幕（显示缩放大于 100% 时也是如此）。此前右侧和底部可能被裁掉，且红色和蓝色互换。
- (Base) Elite Rizer：当 Rizer 被锁定（红色 LED）而无法调整坡度时，其页面和骑行页现在会显示这一点，而不再显示正在跟随坡度。
- (Base) Elite Rizer：被锁定的 Rizer 现在一连接就会显示为已锁定，而不必等到收到坡度。
- (Base) Windows：在没有蓝牙适配器的电脑上，蓝牙权限现在会明确提示并打开蓝牙设置，而不是毫无反应；Wi-Fi 骑行台和游戏手柄无需蓝牙也能被找到。如果 Windows 拒绝开启蓝牙，BikeControl 会提示你并打开设置。

### 7.6.1 (20-11-2026)
**Features**:
- (Base) 通过蓝牙连接 MyWhoosh：在 MyWhoosh 中将 BikeControl 配对为转向设备，即可换挡，并在路口选择路线（长按）。如果网络连接不上，BikeControl 会改为提供蓝牙连接。
- (Pro) 传感器：一个列表显示功率、心率、踏频和速度的来源（包括骑行台），并可用你自己的传感器替换其中任意一项。只有在未连接骑行台时才显示「发送到训练应用」，因为骑行台已经在传输这些数值。
- (Pro) 控制协议：选择自动时，骑行台页面会显示自动选用的协议（例如「自动：FTMS」）。

**Fixes**:
- (Base) Shimano Di2：D-Fly 通道设置现在能识别哪个变速手柄在左、哪个在右，它更改的按键也不会再让自行车换挡。

### 7.6.0 (17-11-2026)
**Features**:
- (Base) Incyclist、Tour du Pain 和 Rampida 现已通过 OpenBikeControl 获得官方支持。
- (Base) CYCPLUS T7 变速拨杆可作为控制器使用：全部八个按键，默认用后方箭头键转向。
- (Pro) OpenBikeControl 应用现在可以实时看到你的虚拟挡位。
- (Base) 更清晰的按键编辑器：操作按用途分组（挡位、骑行台、训练、骑行……），在手机上以底部面板打开。
- (Base) Shimano Di2：第三种设置方式——按照分步指南，自己在 E-TUBE 中设置 D-Fly 通道。
- (Base) Zwift Click V2：你可以选择不解锁就使用右侧控制器。
- 更多试用空间：试用期内每天 120 次按键（之前 80 次），试用期后每天 40 次（之前 15 次）；没有 Pro 时，BikeControl 自带的虚拟变速每天可用 30 分钟（之前 20 分钟）。
- 更清晰的试用：今天还剩 10 次按键时，BikeControl 会提醒你（也会发送通知），试用卡片会显示试用结束后的额度。如果你的训练 App 自己负责换挡，“骑行”页不再推荐 BikeControl 的虚拟变速；在 OpenBikeControl 连接旁，键盘控制会标为可选。
- (Base) KICKR Headwind：风扇可以跟随你的心率（来自连接到 BikeControl 的心率带）或功率，并由你设置启动点和全速点。页面会显示实时读数及对应的风扇速度。
- (Base) Elite Rizer：坡度模拟现在适用于任何智能骑行台。
- (Pro) 骑行台控制（Companion 模式）现在以骑行模式打开：大号 − 和 +，中间是档位、功率、踏频和传动比，其他按钮在下方。点“编辑”可移动图块、调整大小，并添加按钮、数据和音乐控制；也可全屏显示。它的 − 和 + 现在使用 BikeControl 自己的虚拟变速，换挡时会振动。

**Fixes**:
- Zwift：短按也能发出 Ride On 炸弹（Zwift 需要按住按键片刻）。
- Elite 骑行台不再重复显示（WiFi 和蓝牙）。
- Windows：BikeControl 关闭时不再崩溃，也不会因网络、通知或蓝牙错误而崩溃。
- Android：Android 重启后台服务时不再崩溃，“关闭并退出”总能退出应用。
- Shimano Di2：当拨杆不接受设置时，通道设置会正常结束。
- Windows 和 macOS：“截屏”现在可以自行选择文件夹（默认从“图片”开始），不再保存在应用旁边；截图无法保存时也会提示。

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
