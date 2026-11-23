import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

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

  @override
  PwaInstallStatus readStatus() => PwaInstallStatus(
    isMobileBrowser: _callBool('isMobileBrowser'),
    isStandalone: _callBool('isStandalone'),
    canPrompt: _callBool('canPrompt'),
    isIos: _callBool('isIos'),
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
