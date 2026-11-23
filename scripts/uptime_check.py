#!/usr/bin/env python3
"""External uptime and readiness probe for RevoCred production endpoints.

Uses only Python stdlib so it runs identically in GitHub Actions and locally.
"""
from dataclasses import dataclass
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


@dataclass
class CheckSpec:
    name: str
    url: str
    expected_status: int = 200
    expect_json: bool = False
    expect_json_status: str | None = None


@dataclass
class CheckResult:
    name: str
    url: str
    ok: bool
    status_code: int | None
    latency_ms: int
    attempts: int
    detail: str


def build_checks(api_base_url: str, pwa_health_url: str = "") -> list[CheckSpec]:
    base = api_base_url.strip().rstrip("/")
    if not base:
        raise ValueError("API_BASE_URL must not be empty")
    checks = [
        CheckSpec(
            name="API Readiness",
            url=f"{base}/readyz",
            expected_status=200,
            expect_json=True,
            expect_json_status="ready",
        ),
        CheckSpec(
            name="Chat Disclosure",
            url=f"{base}/v1/public/chat-disclosure",
            expected_status=200,
            expect_json=True,
        ),
        CheckSpec(
            name="Privacy Policy",
            url=f"{base}/privacy",
            expected_status=200,
        ),
    ]
    pwa = pwa_health_url.strip()
    if pwa:
        checks.append(CheckSpec(name="PWA", url=pwa, expected_status=200))
    return checks


def _probe_once(spec: CheckSpec, timeout: float, opener=urllib.request.urlopen) -> tuple[bool, int | None, int, str]:
    req = urllib.request.Request(
        spec.url,
        method="GET",
        headers={"User-Agent": "RevoCred-Uptime-Check/1.0"},
    )
    started = time.monotonic()
    try:
        with opener(req, timeout=timeout) as resp:
            status = getattr(resp, "status", None) or resp.getcode()
            body = resp.read()
    except urllib.error.HTTPError as exc:
        elapsed = int((time.monotonic() - started) * 1000)
        return False, exc.code, elapsed, f"HTTP {exc.code}"
    except Exception as exc:  # noqa: BLE001
        elapsed = int((time.monotonic() - started) * 1000)
        return False, None, elapsed, str(exc)

    elapsed = int((time.monotonic() - started) * 1000)
    if status != spec.expected_status:
        return False, status, elapsed, f"HTTP {status} (expected {spec.expected_status})"
    if not body.strip():
        return False, status, elapsed, "empty response body"
    if spec.expect_json:
        try:
            payload = json.loads(body.decode("utf-8"))
        except Exception as exc:  # noqa: BLE001
            return False, status, elapsed, f"invalid JSON: {exc}"
        if not isinstance(payload, dict):
            return False, status, elapsed, "expected JSON object"
        if spec.expect_json_status is not None:
            actual = payload.get("status")
            if actual != spec.expect_json_status:
                return (
                    False,
                    status,
                    elapsed,
                    f"JSON status={actual!r} (expected {spec.expect_json_status!r})",
                )
    return True, status, elapsed, "ok"


def run_check(
    spec: CheckSpec,
    *,
    retries: int = 3,
    retry_delay: float = 5.0,
    timeout: float = 10.0,
    opener=urllib.request.urlopen,
    sleep_fn=time.sleep,
) -> CheckResult:
    attempts = max(1, retries)
    last_status = None
    last_latency = 0
    last_detail = "unknown error"
    for attempt in range(1, attempts + 1):
        ok, status, latency_ms, detail = _probe_once(spec, timeout=timeout, opener=opener)
        last_status, last_latency, last_detail = status, latency_ms, detail
        if ok:
            return CheckResult(
                name=spec.name,
                url=spec.url,
                ok=True,
                status_code=status,
                latency_ms=latency_ms,
                attempts=attempt,
                detail=detail,
            )
        if attempt < attempts:
            sleep_fn(retry_delay * attempt)
    return CheckResult(
        name=spec.name,
        url=spec.url,
        ok=False,
        status_code=last_status,
        latency_ms=last_latency,
        attempts=attempts,
        detail=last_detail,
    )


def format_alert_message(results: list[CheckResult], run_url: str = "") -> str:
    failed = [r for r in results if not r.ok]
    lines = [f"RevoCred Uptime Alert: {len(failed)}/{len(results)} endpoint check(s) failed"]
    for item in failed:
        lines.append(
            f"- {item.name} ({item.url}): {item.detail} after {item.attempts} attempt(s) ({item.latency_ms}ms)"
        )
    if run_url:
        lines.append(f"Workflow run: {run_url}")
    return "\n".join(lines)


def build_webhook_payload(webhook_url: str, results: list[CheckResult], run_url: str = "") -> dict:
    message = format_alert_message(results, run_url=run_url)
    host = (urllib.parse.urlparse(webhook_url).hostname or "").lower()
    if host.endswith("discord.com") or host.endswith("discordapp.com"):
        return {"content": message}
    if host.endswith("hooks.slack.com"):
        return {"text": message}
    return {
        "text": message,
        "content": message,
        "status": "failed",
        "run_url": run_url,
        "failures": [
            {
                "name": r.name,
                "url": r.url,
                "status_code": r.status_code,
                "latency_ms": r.latency_ms,
                "attempts": r.attempts,
                "detail": r.detail,
            }
            for r in results
            if not r.ok
        ],
    }


def send_webhook_alert(
    webhook_url: str,
    results: list[CheckResult],
    *,
    run_url: str = "",
    timeout: float = 10.0,
    opener=urllib.request.urlopen,
) -> None:
    payload = build_webhook_payload(webhook_url, results, run_url=run_url)
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        webhook_url,
        data=data,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "User-Agent": "RevoCred-Uptime-Check/1.0",
        },
    )
    with opener(req, timeout=timeout) as resp:
        status = getattr(resp, "status", None) or resp.getcode()
        if status < 200 or status >= 300:
            raise RuntimeError(f"webhook returned HTTP {status}")


def render_markdown_summary(results: list[CheckResult], pwa_skipped: bool) -> str:
    lines = [
        "### RevoCred Uptime Check",
        "",
        "| Check | URL | Result | HTTP | Latency | Attempts | Detail |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]
    for r in results:
        icon = "PASS" if r.ok else "FAIL"
        code = str(r.status_code) if r.status_code is not None else "-"
        lines.append(
            f"| {r.name} | `{r.url}` | {icon} | {code} | {r.latency_ms} ms | {r.attempts} | {r.detail} |"
        )
    if pwa_skipped:
        lines.append("")
        lines.append(
            "_PWA check skipped. Set repository variable `PWA_HEALTH_URL` (e.g. `https://revocred-pwa.vercel.app` or `https://app.revocred.com`) to enable it._"
        )
    return "\n".join(lines) + "\n"


def _github_run_url() -> str:
    server = os.environ.get("GITHUB_SERVER_URL", "").strip().rstrip("/")
    repo = os.environ.get("GITHUB_REPOSITORY", "").strip()
    run_id = os.environ.get("GITHUB_RUN_ID", "").strip()
    if server and repo and run_id:
        return f"{server}/{repo}/actions/runs/{run_id}"
    return ""


def main() -> int:
    api_base_url = os.environ.get("API_BASE_URL", "https://api.revocred.com").strip() or "https://api.revocred.com"
    pwa_health_url = os.environ.get("PWA_HEALTH_URL", "").strip()
    webhook_url = os.environ.get("UPTIME_ALERT_WEBHOOK_URL", "").strip()
    retries = int(os.environ.get("UPTIME_RETRIES", "3"))
    retry_delay = float(os.environ.get("UPTIME_RETRY_DELAY_SECONDS", "5"))
    timeout = float(os.environ.get("UPTIME_TIMEOUT_SECONDS", "10"))

    specs = build_checks(api_base_url, pwa_health_url)
    results = [
        run_check(spec, retries=retries, retry_delay=retry_delay, timeout=timeout)
        for spec in specs
    ]

    for r in results:
        state = "PASS" if r.ok else "FAIL"
        code = str(r.status_code) if r.status_code is not None else "ERR"
        print(
            f"[{state}] {r.name:<16} {code:<4} {r.latency_ms:>5}ms  attempts={r.attempts}  url={r.url}  detail={r.detail}"
        )

    pwa_skipped = not bool(pwa_health_url)
    if pwa_skipped:
        print(
            "[SKIP] PWA              -        -    set PWA_HEALTH_URL (e.g. https://revocred-pwa.vercel.app or https://app.revocred.com) to enable"
        )

    summary_path = os.environ.get("GITHUB_STEP_SUMMARY", "").strip()
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as fh:
            fh.write(render_markdown_summary(results, pwa_skipped=pwa_skipped))

    failures = [r for r in results if not r.ok]
    if not failures:
        return 0

    if webhook_url:
        try:
            send_webhook_alert(webhook_url, results, run_url=_github_run_url(), timeout=timeout)
            print("Sent uptime failure alert to configured webhook.")
        except Exception as exc:  # noqa: BLE001
            print(f"Failed to send uptime alert webhook: {exc}", file=sys.stderr)
    else:
        print("No UPTIME_ALERT_WEBHOOK_URL secret configured; skipping webhook notification.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
