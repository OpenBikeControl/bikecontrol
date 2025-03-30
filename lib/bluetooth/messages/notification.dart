class BaseNotification {}

class LogNotification extends BaseNotification {
  final String message;

  LogNotification(this.message);

  @override
  String toString() {
    return message;
  }
}
