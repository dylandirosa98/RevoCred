#!/usr/bin/env python3
"""Build/start or stop the real-data local preview (not a production server)."""
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import time
import urllib.request
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
STATE = ROOT / '.local'


def env_file(path):
    return dict(line.split('=', 1) for line in path.read_text().splitlines() if line and not line.startswith('#'))


def stop():
    record = STATE / 'processes.json'
    if not record.exists():
        return
    for entry in json.loads(record.read_text()):
        try:
            command = Path(f"/proc/{entry['pid']}/cmdline").read_bytes().replace(b'\0', b' ').decode()
            if str(STATE) in command:
                os.killpg(entry['pid'], signal.SIGTERM)
        except (ProcessLookupError, FileNotFoundError):
            pass
    record.unlink()


def main():
    if len(sys.argv) > 1 and sys.argv[1] == 'stop':
        stop()
        print('Stopped managed local preview processes.')
        return
    stop()
    for port in (8082, 8083):
        with socket.socket() as sock:
            if sock.connect_ex(('127.0.0.1', port)) == 0:
                raise SystemExit(f'Port {port} is occupied; stop the existing project server before starting this preview.')
    values = env_file(ROOT / 'revocred-api/.env.local')
    frontend = env_file(ROOT / '.env.local')
    for value in (values['DATABASE_URL'], values['SUPABASE_URL'], frontend['SUPABASE_URL'], frontend['REVOCRED_API_URL']):
        if urlparse(value).hostname not in ('localhost', '127.0.0.1'):
            raise SystemExit('Local preview refuses non-loopback backend configuration.')
    if frontend['REVOCRED_USE_MOCKS'] != 'false':
        raise SystemExit('Run make local-setup to configure real local mode.')
    STATE.mkdir(exist_ok=True)
    subprocess.run([str(ROOT / 'revocred-api/bin/goose'), '-dir', 'migrations', 'up'], cwd=ROOT / 'revocred-api', env={**os.environ, 'GOOSE_DRIVER': 'postgres', 'GOOSE_DBSTRING': values['DATABASE_URL']}, check=True)
    binary = STATE / 'revocred-api'
    subprocess.run(['go', 'build', '-o', str(binary), './cmd/api'], cwd=ROOT / 'revocred-api', check=True)
    flutter = os.environ.get('FLUTTER', str(Path.home() / '.local/share/flutter/bin/flutter'))
    # Flutter's custom web output path has omitted generated asset manifests in
    # some SDK releases. Build into Flutter's canonical directory so fonts,
    # images and AssetManifest files are always served together.
    subprocess.run([flutter, 'build', 'web', '--release', '--no-web-resources-cdn', '--dart-define-from-file=../.env.local'], cwd=ROOT / 'revocred_flutter', check=True)
    web_root = ROOT / 'revocred_flutter' / 'build' / 'web'
    entries = []
    try:
        for name, command, environment in (
            ('api', [str(binary)], {**os.environ, **values, 'PORT': '8082'}),
            ('web', [sys.executable, '-m', 'http.server', '8083', '--bind', '127.0.0.1', '--directory', str(web_root)], os.environ),
        ):
            with (STATE / f'{name}.log').open('ab') as log:
                process = subprocess.Popen(command, env=environment, stdout=log, stderr=log, start_new_session=True)
            entries.append({'name': name, 'pid': process.pid})
        (STATE / 'processes.json').write_text(json.dumps(entries))
        for _ in range(50):
            try:
                with urllib.request.urlopen('http://127.0.0.1:8082/readyz', timeout=2) as response:
                    if response.status == 200:
                        print('Real local preview: http://127.0.0.1:8083 | API: http://127.0.0.1:8082 | logs: .local/')
                        return
            except OSError:
                time.sleep(.2)
        raise RuntimeError('API startup failed; inspect .local/api.log')
    except BaseException:
        stop()
        raise


if __name__ == '__main__':
    main()
