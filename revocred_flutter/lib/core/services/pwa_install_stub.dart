import 'pwa_install.dart';

class _UnsupportedPwaInstallClient implements PwaInstallClient {
  const _UnsupportedPwaInstallClient();

  @override
  PwaInstallStatus readStatus() => const PwaInstallStatus.unsupported();

  @override
  Stream<PwaInstallStatus> get statusChanges => const Stream.empty();

  @override
  Future<bool> promptInstall() async => false;
}

PwaInstallClient createPwaInstallClient() =>
    const _UnsupportedPwaInstallClient();
