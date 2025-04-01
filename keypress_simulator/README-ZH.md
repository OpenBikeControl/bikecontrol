> **🚀 快速发布您的应用**: 试试 [Fastforge](https://fastforge.dev) - 构建、打包和分发您的 Flutter 应用最简单的方式。

# keypress_simulator

[![pub version][pub-image]][pub-url] [![][discord-image]][discord-url]

[pub-image]: https://img.shields.io/pub/v/keypress_simulator.svg
[pub-url]: https://pub.dev/packages/keypress_simulator
[discord-image]: https://img.shields.io/discord/884679008049037342.svg
[discord-url]: https://discord.gg/zPa6EZ2jqb

这个插件允许 Flutter 桌面应用模拟按键操作。

---

[English](./README.md) | 简体中文

---

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [平台支持](#%E5%B9%B3%E5%8F%B0%E6%94%AF%E6%8C%81)
- [快速开始](#%E5%BF%AB%E9%80%9F%E5%BC%80%E5%A7%8B)
  - [安装](#%E5%AE%89%E8%A3%85)
  - [用法](#%E7%94%A8%E6%B3%95)
- [谁在用使用它？](#%E8%B0%81%E5%9C%A8%E7%94%A8%E4%BD%BF%E7%94%A8%E5%AE%83)
- [许可证](#%E8%AE%B8%E5%8F%AF%E8%AF%81)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## 平台支持

| Linux | macOS | Windows |
| :---: | :---: | :-----: |
|  ➖   |  ✔️   |   ✔️    |

## 快速开始

### 安装

将此添加到你的软件包的 pubspec.yaml 文件：

```yaml
dependencies:
  keypress_simulator: ^0.2.0
```

### 用法

```dart
import 'package:keypress_simulator/keypress_simulator.dart';

// 1. Simulate pressing ⌘ + C

// 1.1 Simulate key down
await keyPressSimulator.simulateKeyDown(
  PhysicalKeyboardKey.keyC,
  [ModifierKey.metaModifier],
);

// 1.2 Simulate key up
await keyPressSimulator.simulateKeyUp(
  PhysicalKeyboardKey.keyC,
  [ModifierKey.metaModifier],
);

// 2. Simulate long pressing ⌘ + space

// 2.1. Simulate key down
await keyPressSimulator.simulateKeyDown(
  PhysicalKeyboardKey.space,
  [ModifierKey.metaModifier],
);

await Future.delayed(const Duration(seconds: 5));

// 2.2. Simulate key up
await keyPressSimulator.simulateKeyUp(
  PhysicalKeyboardKey.space,
  [ModifierKey.metaModifier],
);
```

> 请看这个插件的示例应用，以了解完整的例子。

## 谁在用使用它？

- [Biyi (比译)](https://biyidev.com/) - 一个便捷的翻译和词典应用程序。

## 许可证

[MIT](./LICENSE)
