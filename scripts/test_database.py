#!/usr/bin/env python3
"""Run migrations, isolation tests and a restore drill in disposable PostgreSQL.

Never reads application .env files or connects to a configured production DB.
"""
import os
from pathlib import Path
import secrets
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def wait_for_database(name):
    # The image's init server accepts Unix-socket connections before shutting
    # down for the final server. Only the final server accepts TCP connections.
    for _ in range(60):
        result = subprocess.run(
            ['docker', 'exec', name, 'pg_isready', '-h', '127.0.0.1', '-U', 'postgres'],
            capture_output=True)
        if result.returncode == 0:
            return
        time.sleep(1)
    raise RuntimeError('test database did not become ready')


def main():
    name = "revocred-test-" + secrets.token_hex(5)
    password = secrets.token_urlsafe(24)
    try:
        run("docker", "run", "--detach", "--name", name, "--publish", "127.0.0.1::5432",
            "--env", "POSTGRES_DB=revocred_test", "--env", "POSTGRES_PASSWORD=" + password,
            "postgres:15-alpine", stdout=subprocess.DEVNULL)
        wait_for_database(name)
        port = subprocess.check_output(["docker", "port", name, "5432/tcp"], text=True).strip().split(":")[-1]
        url = f"postgresql://postgres:{password}@127.0.0.1:{port}/revocred_test?sslmode=disable"
        run("docker", "exec", name, "psql", "-U", "postgres", "-d", "revocred_test", "-v", "ON_ERROR_STOP=1", "-c",
            "CREATE SCHEMA auth; CREATE TABLE auth.users(id uuid PRIMARY KEY, email text); CREATE ROLE anon; CREATE ROLE authenticated;")
        # Goose supports env configuration so credentials do not appear in its args.
        env = {**os.environ, "GOOSE_DRIVER": "postgres", "GOOSE_DBSTRING": url,
               "REVOCRED_TEST_DATABASE_URL": url}
        run(str(ROOT / "revocred-api/bin/goose"), "-dir", "migrations", "up", cwd=ROOT / "revocred-api", env=env)
        run("go", "test", "-race", "-count=1", "./internal/store", cwd=ROOT / "revocred-api", env=env)
        dump = subprocess.check_output(["docker", "exec", name, "pg_dump", "-U", "postgres", "-Fc", "revocred_test"])
        run("docker", "exec", name, "createdb", "-U", "postgres", "revocred_restore")
        run("docker", "exec", "-i", name, "pg_restore", "-U", "postgres", "--exit-on-error", "-d", "revocred_restore", input=dump)
        count = subprocess.check_output(["docker", "exec", name, "psql", "-U", "postgres", "-d", "revocred_restore", "-Atc",
            "SELECT count(*) FROM revocred.catalog_cards WHERE is_active AND data_kind='issuer_snapshot'"], text=True).strip()
        if count != "15":
            raise AssertionError("restored catalog count mismatch: " + count)
        print("Database verification passed: migrations, runtime-role isolation, account lifecycle, immutable snapshots, and backup restore.")
    finally:
        subprocess.run(["docker", "rm", "--force", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == "__main__":
    main()
