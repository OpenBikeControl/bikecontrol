//INFO: This is a stub - contact me if you need the full implementation.
//
// The full implementation serializes start/stop operations so two un-awaited
// lifecycle calls can never interleave. This stub runs each operation
// immediately.

/// Runs operations one at a time, in call order.
class SerializedLifecycle {
  Future<T> run<T>(Future<T> Function() op) => op();
}
