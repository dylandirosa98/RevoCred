import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'pwa_install.dart';

class _WebPwaInstallClient implements PwaInstallClient {
  _WebPwaInstallClient() {
    _listener = ((web.Event _) {
      if (!_controller.isClosed) {
        _controller.add(readStatus());
      }
    }).toJS;
    web.window.addEventListener('revocred-pwa-change', _listener);
  }

  final _controller = StreamController<PwaInstallStatus>.broadcast();
  late final JSFunction _listener;

  JSObject? get _bridge {
    final value = web.window.getProperty('__revocredPwa'.toJS);
    return value.isA<JSObject>() ? value as JSObject : null;
  }

  bool _callBool(String method) {
    final bridge = _bridge;
    if (bridge == null || !bridge.has(method)) return false;
    try {
      final result = bridge.callMethod<JSAny?>(method.toJS);
      return result.isA<JSBoolean>() && (result as JSBoolean).toDart;
    } catch (_) {
      return false;
    }
  }

  double _readInset(JSObject obj, String key) {
    final value = obj.getProperty(key.toJS);
    if (!value.isA<JSNumber>()) return 0;
    final parsed = (value as JSNumber).toDartDouble;
    return parsed.isFinite && parsed > 0 ? parsed : 0;
  }

  EdgeInsets _readSafeAreaInsets() {
    final bridge = _bridge;
    if (bridge == null || !bridge.has('safeAreaInsets')) {
      return EdgeInsets.zero;
    }
    try {
      final result = bridge.callMethod<JSAny?>('safeAreaInsets'.toJS);
      if (!result.isA<JSObject>()) return EdgeInsets.zero;
      final obj = result as JSObject;
      return EdgeInsets.fromLTRB(
        _readInset(obj, 'left'),
        _readInset(obj, 'top'),
        _readInset(obj, 'right'),
        _readInset(obj, 'bottom'),
      );
    } catch (_) {
      return EdgeInsets.zero;
    }
  }

  @override
  PwaInstallStatus readStatus() => PwaInstallStatus(
    isMobileBrowser: _callBool('isMobileBrowser'),
    isStandalone: _callBool('isStandalone'),
    canPrompt: _callBool('canPrompt'),
    isIos: _callBool('isIos'),
    safeAreaInsets: _readSafeAreaInsets(),
  );

  @override
  Stream<PwaInstallStatus> get statusChanges => _controller.stream;

  @override
  Future<bool> promptInstall() async {
    final bridge = _bridge;
    if (bridge == null || !bridge.has('promptInstall')) return false;
    try {
      final promise = bridge.callMethod<JSPromise<JSString>>(
        'promptInstall'.toJS,
      );
      final outcome = (await promise.toDart).toDart;
      return outcome == 'accepted';
    } catch (_) {
      return false;
    }
  }
}

PwaInstallClient createPwaInstallClient() => _WebPwaInstallClient();
