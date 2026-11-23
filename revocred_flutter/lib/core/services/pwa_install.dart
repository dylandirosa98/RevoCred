import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pwa_install_stub.dart'
    if (dart.library.js_interop) 'pwa_install_web.dart';

class PwaInstallStatus {
  const PwaInstallStatus({
    required this.isMobileBrowser,
    required this.isStandalone,
    required this.canPrompt,
    required this.isIos,
  });

  const PwaInstallStatus.unsupported()
    : isMobileBrowser = false,
      isStandalone = false,
      canPrompt = false,
      isIos = false;

  final bool isMobileBrowser;
  final bool isStandalone;
  final bool canPrompt;
  final bool isIos;

  bool get shouldShowHint => isMobileBrowser && !isStandalone;
}

abstract class PwaInstallClient {
  PwaInstallStatus readStatus();
  Stream<PwaInstallStatus> get statusChanges;
  Future<bool> promptInstall();
}

final pwaInstallClientProvider = Provider<PwaInstallClient>(
  (ref) => createPwaInstallClient(),
);
