#!/usr/bin/env python3
"""Secret-free native compile fixture and simulator launch smoke; never distribute."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import time

from ios_release import (
    APP, ROOT, FLUTTER_REVISION, flutter_executable, load_config,
    require_apple_toolchain, require_flutter_revision, validate_project,
)


def write_fixture(path):
    config = json.loads((ROOT / 'config/ios-release.example.json').read_text())
    config.update(REVOCRED_API_URL='https://api.example.test',
                  SUPABASE_URL='https://project.example.test',
                  SUPABASE_ANON_KEY='sb_publishable_compile_fixture_only')
    path.write_text(json.dumps(config))
    load_config(path, allow_fixture=True)


def choose_simulators(payload):
    candidates = []
    for runtime, devices in payload['devices'].items():
        match = re.search(r'iOS-(\d+)-(\d+)', runtime)
        if match and int(match[1]) >= 26:
            candidates.append((tuple(map(int, match.groups())), devices))
    for _, devices in sorted(candidates, key=lambda pair: pair[0], reverse=True):
        chosen = [next((d for d in devices if d.get('isAvailable') and
                        d['name'].startswith(family)), None) for family in ('iPhone', 'iPad')]
        if all(chosen):
            return chosen
    raise ValueError('Require available iOS 26+ iPhone AND iPad simulators; no smoke silently skipped.')


def select_xcode():
    candidates = []
    for app in Path('/Applications').glob('Xcode*.app'):
        version_file = app / 'Contents/version.plist'
        if not version_file.is_file():
            continue
        version = plistlib.loads(version_file.read_bytes()).get('CFBundleShortVersionString', '')
        parts = re.match(r'(\d+)\.(\d+)', version)
        if parts and int(parts[1]) >= 26:
            candidates.append((tuple(map(int, parts.groups())), app))
    if not candidates:
        raise ValueError('Runner image has no Xcode 26+; do not fall back to an older SDK.')
    _, app = max(candidates, key=lambda pair: (pair[0], str(pair[1])))
    developer = str(app / 'Contents/Developer')
    os.environ['DEVELOPER_DIR'] = developer
    require_apple_toolchain()
    with open(os.environ['GITHUB_ENV'], 'a') as stream:
        stream.write('DEVELOPER_DIR=' + developer + '\n')
    print('Selected ' + str(app))


def run(command, output, name, *, cwd=APP, timeout=900):
    # Only known fixture builds call this. Never point it at signing/public config secrets.
    with (output / (name + '.log')).open('w') as log:
        result = subprocess.run(command, cwd=cwd, stdout=log,
                                stderr=subprocess.STDOUT, timeout=timeout)
    if result.returncode:
        raise ValueError(name + ' failed; inspect its fixture-only artifact log.')


def smoke(device, app, output):
    udid = device['udid']
    family = 'iphone' if device['name'].startswith('iPhone') else 'ipad'
    sim = ['xcrun', 'simctl']
    with (app / 'Info.plist').open('rb') as stream:
        bundle = plistlib.load(stream)['CFBundleIdentifier']
    try:
        if device.get('state') != 'Booted':
            run(sim + ['boot', udid], output, family + '-boot', timeout=60)
        run(sim + ['bootstatus', udid, '-b'], output, family + '-bootstatus', timeout=240)
        run(sim + ['install', udid, str(app)], output, family + '-install', timeout=120)
        run(sim + ['launch', '--terminate-running-process', udid, bundle],
            output, family + '-launch', timeout=60)
        time.sleep(15)
        processes = subprocess.check_output(sim + ['spawn', udid, 'launchctl', 'list'], text=True, timeout=30)
        alive = any(bundle in line and line.split()[0].isdigit() for line in processes.splitlines())
        run(sim + ['io', udid, 'screenshot', str(output / (family + '-launch.png'))],
            output, family + '-screenshot', timeout=30)
        if not alive:
            raise ValueError(family + ' app exited within 15 seconds of cold launch.')
        return {'device': device['name'], 'udid': udid, 'status': 'launch-process-alive',
                'acceptance': 'Not a functional/live-service test; inspect launch screenshot.'}
    finally:
        # Fixture-only Runner logs, not the entire system log or private user files.
        try:
            with (output / (family + '-runtime.log')).open('w') as log:
                subprocess.run(sim + ['spawn', udid, 'log', 'show', '--last', '2m', '--style', 'compact',
                                      '--predicate', 'process == "Runner"'],
                               stdout=log, stderr=subprocess.STDOUT, timeout=60, check=False)
        finally:
            subprocess.run(sim + ['shutdown', udid], capture_output=True, timeout=60, check=False)


def native_build(output, config, result):
    require_apple_toolchain()
    flutter = flutter_executable()
    # A fresh SDK prints bootstrap/pub output before its first machine JSON.
    # Initialize separately so version inspection reads clean JSON and failures
    # retain a bounded fixture-only diagnostic artifact.
    run([flutter, '--version'], output, 'flutter-bootstrap', timeout=300)
    require_flutter_revision(flutter)
    run(['xcodebuild', '-version'], output, 'xcode-version', timeout=30)
    run(['xcrun', '--sdk', 'iphoneos', '--show-sdk-version'], output, 'ios-sdk', timeout=30)
    run([flutter, '--version', '--machine'], output, 'flutter-version', timeout=120)
    run([flutter, 'pub', 'get', '--enforce-lockfile'], output, 'pub-get', timeout=300)
    define = '--dart-define-from-file=' + str(config)
    run([flutter, 'build', 'ios', '--release', '--no-codesign', define],
        output, 'unsigned-device-build', timeout=1200)
    device_app = APP / 'build/ios/iphoneos/Runner.app'
    validate_built_app(device_app)
    run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(device_app),
         str(output / 'unsigned-device-compile-fixture.zip')], output, 'package-device', timeout=180)
    result['unsigned_device_compile'] = 'passed'
    run([flutter, 'build', 'ios', '--simulator', '--debug', '--no-codesign', define],
        output, 'simulator-build', timeout=1200)
    simulator_app = APP / 'build/ios/iphonesimulator/Runner.app'
    validate_built_app(simulator_app)
    run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(simulator_app),
         str(output / 'simulator-compile-fixture.zip')], output, 'package-simulator', timeout=180)
    result['simulator_compile'] = 'passed'
    devices = json.loads(subprocess.check_output(
        ['xcrun', 'simctl', 'list', 'devices', 'available', '--json'], text=True, timeout=30))
    for device in choose_simulators(devices):
        result['simulator_smoke'].append(smoke(device, simulator_app, output))


def validate_built_app(app):
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    expected = validate_project()
    if info.get('CFBundleIdentifier') != expected:
        raise ValueError('Built bundle identifier differs from the project.')
    if info.get('ITSAppUsesNonExemptEncryption') is not False:
        raise ValueError('Built encryption declaration is missing.')
    privacy = plistlib.loads((app / 'PrivacyInfo.xcprivacy').read_bytes())
    if privacy.get('NSPrivacyTracking') is not False:
        raise ValueError('Built privacy manifest is missing or changed.')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', default=str(ROOT / '.local/release-readiness'))
    parser.add_argument('--preflight-only', action='store_true')
    parser.add_argument('--select-xcode', action='store_true')
    args = parser.parse_args(argv)
    if args.select_xcode:
        select_xcode()
        return 0
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    config = output / 'compile-fixture.json'
    result = {'kind': 'compile-fixture-only', 'testflight_ready': False, 'signed': False,
              'flutter_revision': FLUTTER_REVISION, 'commit': os.environ.get('GITHUB_SHA', 'local-dirty-unverified'),
              'status': 'failed', 'unsigned_device_compile': 'unverified',
              'simulator_compile': 'unverified', 'simulator_smoke': []}
    try:
        write_fixture(config)
        validate_project()
        if args.preflight_only:
            result['status'] = 'static-passed-native-unverified'
        else:
            native_build(output, config, result)
            result['status'] = 'native-fixture-passed-not-distributable'
        return 0
    except (ValueError, OSError, subprocess.SubprocessError):
        # Never echo environment, config, command arguments or unknown exception payloads.
        print('iOS fixture verification failed; inspect fixture-only logs. No signing or upload occurred.')
        return 1
    finally:
        (output / 'build-result.json').write_text(json.dumps(result, indent=2) + '\n')
        config.unlink(missing_ok=True)
        print('Fixture evidence: ' + str(output / 'build-result.json'))


if __name__ == '__main__':
    raise SystemExit(main())
