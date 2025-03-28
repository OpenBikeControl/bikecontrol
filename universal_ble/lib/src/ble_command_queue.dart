import 'package:universal_ble/src/queue.dart';
import 'package:universal_ble/universal_ble.dart';

/// Set queue type and queue commands
class BleCommandQueue {
  QueueType queueType;
  Duration? timeout = const Duration(seconds: 10);
  OnQueueUpdate? onQueueUpdate;
  final Map<String, Queue> _queueMap = {};
  static const String globalQueueId = 'global';

  BleCommandQueue({this.queueType = QueueType.global});

  Future<T> queueCommand<T>(
    Future<T> Function() command, {
    bool withTimeout = true,
    String? deviceId,
    Duration? timeout,
  }) {
    Duration? duration = timeout ?? (withTimeout ? this.timeout : null);
    return switch (queueType) {
      QueueType.global => _queue().add(command, duration),
      QueueType.perDevice => _queue(deviceId).add(command, duration),
      QueueType.none =>
        duration != null ? command().timeout(duration) : command(),
    };
  }

  Queue _queue([String? id = globalQueueId]) =>
      _queueMap[id] ?? _newQueue(id ?? globalQueueId);

  Queue _newQueue(String id) {
    final queue = Queue();
    queue.onRemainingItemsUpdate = (int items) {
      try {
        onQueueUpdate?.call(id, items);
      } catch (_) {}
    };
    _queueMap[id] = queue;
    return queue;
  }
}
