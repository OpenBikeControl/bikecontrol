import 'package:flutter/material.dart';

typedef RenderLoadCallback = Widget Function();
typedef OnErrorCallback = void Function(BuildContext context, dynamic error);
typedef OnLoadCallback = void Function(bool isLoading);
typedef RenderChildCallback = Widget Function(bool isLoading, VoidCallback? onTap);
typedef FutureCallback = Future Function();

enum LoadingState { Error, Loading, Success }

class LoadingWidget extends StatefulWidget {
  const LoadingWidget({
    super.key,
    this.renderLoad,
    this.renderChild,
    this.onErrorCallback,
    this.futureCallback,
    this.onLoadCallback,
  });

  final RenderLoadCallback? renderLoad;
  final RenderChildCallback? renderChild;
  final OnErrorCallback? onErrorCallback;
  final OnLoadCallback? onLoadCallback;
  final FutureCallback? futureCallback;

  @override
  State<StatefulWidget> createState() => LoadingWidgetState();
}

class LoadingWidgetState extends State<LoadingWidget> {
  var _loadingState = LoadingState.Success;
  dynamic _error;

  Future<void> reloadState() {
    return _initState();
  }

  Future<void> _initState() async {
    if (!mounted) {
      return;
    }

    if (widget.onLoadCallback != null) {
      widget.onLoadCallback!(true);
    }
    setState(() {
      _loadingState = LoadingState.Loading;
    });

    try {
      await widget.futureCallback!();

      if (!mounted) {
        return;
      }

      if (widget.onLoadCallback != null) {
        widget.onLoadCallback!(false);
      }

      setState(() {
        _loadingState = LoadingState.Success;
      });
    } catch (e) {
      if (widget.onLoadCallback != null) {
        widget.onLoadCallback!(false);
      }
      debugPrint(e.toString());
      if (mounted) {
        setState(() {
          _error = e;
          _loadingState = LoadingState.Error;
          if (widget.onErrorCallback != null) {
            widget.onErrorCallback!(context, _error);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_error.toString())));
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingState == LoadingState.Loading && widget.renderLoad != null) {
      return widget.renderLoad!();
    }

    final isLoading = _loadingState == LoadingState.Loading;
    return widget.renderChild!(isLoading, isLoading ? null : () => reloadState());
  }
}
