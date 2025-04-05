class SingleLineException implements Exception {
  final String message;

  SingleLineException(this.message);

  @override
  String toString() {
    return message;
  }
}
