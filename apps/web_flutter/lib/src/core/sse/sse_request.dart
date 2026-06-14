class SseCancellationToken {
  bool _isCancelled = false;
  void Function()? _cancelRequest;

  bool get isCancelled => _isCancelled;

  void bind(void Function()? cancelRequest) {
    _cancelRequest = cancelRequest;
    if (_isCancelled) {
      cancelRequest?.call();
    }
  }

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    _cancelRequest?.call();
  }
}

class SseRequestException implements Exception {
  const SseRequestException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
