import unittest
import tempfile
from pathlib import Path

from share_tunnel import (
    build_api_origins,
    build_share_defines,
    discover_tunnels,
    find_loopback_endpoints,
    missing_redirect_allowances,
    share_paths,
    write_env_file,
    env_file,
    build_share_api,
)


TUNNEL_LOG = """2026-09-26T07:02:13Z INF Requesting new quick Tunnel on trycloudflare.com...
2026-09-26T07:02:19Z INF |  https://fitting-letting-athletics-losses.trycloudflare.com     |
2026-09-26T07:02:19Z INF Registered tunnel connection connIndex=0
"""


class DiscoverTunnelsTest(unittest.TestCase):
    def test_reads_the_public_url_behind_a_port(self):
        self.assertEqual(
            discover_tunnels({8083: TUNNEL_LOG}),
            {8083: "https://fitting-letting-athletics-losses.trycloudflare.com"},
        )

    def test_ignores_a_log_that_never_got_a_public_url(self):
        self.assertEqual(discover_tunnels({8083: "ERR connection refused\n"}), {})

    def test_ignores_a_non_https_public_url(self):
        self.assertEqual(discover_tunnels({8083: "http://tunnel.example.test\n"}), {})

    def test_reads_each_port_separately(self):
        logs = {
            8082: TUNNEL_LOG.replace("fitting-letting-athletics-losses", "tape-certified-helped-justice"),
            54321: TUNNEL_LOG.replace("fitting-letting-athletics-losses", "electoral-uniform-movie-walks"),
        }
        self.assertEqual(
            discover_tunnels(logs),
            {
                8082: "https://tape-certified-helped-justice.trycloudflare.com",
                54321: "https://electoral-uniform-movie-walks.trycloudflare.com",
            },
        )


class BuildShareDefinesTest(unittest.TestCase):
    frontend = {
        "REVOCRED_USE_MOCKS": "false",
        "REVOCRED_API_URL": "http://127.0.0.1:8082",
        "SUPABASE_URL": "http://127.0.0.1:54321",
        "SUPABASE_ANON_KEY": "public-anon-key",
    }

    def test_points_the_client_at_the_public_tunnels(self):
        self.assertEqual(
            build_share_defines(
                self.frontend,
                {8082: "https://api.example.test", 54321: "https://auth.example.test", 8083: "https://app.example.test"},
            ),
            {
                "REVOCRED_USE_MOCKS": "false",
                "REVOCRED_API_URL": "https://api.example.test",
                "SUPABASE_URL": "https://auth.example.test",
                "SUPABASE_ANON_KEY": "public-anon-key",
                "REVOCRED_AUTH_REDIRECT_URL": "https://app.example.test",
            },
        )

    def test_refuses_to_publish_a_half_discovered_stack(self):
        for tunnels in ({}, {8082: "https://api.example.test"}):
            with self.subTest(tunnels=tunnels), self.assertRaises(ValueError):
                build_share_defines(self.frontend, tunnels)

    def test_refuses_a_non_https_tunnel(self):
        with self.assertRaises(ValueError):
            build_share_defines(self.frontend, {
                8082: "http://api.example.test", 54321: "https://auth.example.test", 8083: "https://app.example.test",
            })


class BuildApiOriginsTest(unittest.TestCase):
    existing = "http://localhost:8081,http://127.0.0.1:8083"

    def test_keeps_local_origins_and_adds_the_tunnel_web_origin(self):
        self.assertEqual(
            build_api_origins(self.existing, "https://app.example.test/"),
            "http://localhost:8081,http://127.0.0.1:8083,https://app.example.test",
        )

    def test_is_idempotent_and_survives_repeated_tunnel_rotation(self):
        # A quick tunnel gets a new hostname on every restart, so the previous
        # one is dead and must not linger in the allow list.
        one = "https://fitting-letting-athletics-losses.trycloudflare.com"
        two = "https://tape-certified-helped-justice.trycloudflare.com"
        first = build_api_origins(self.existing, one)
        second = build_api_origins(first, one)
        rotated = build_api_origins(second, two)
        self.assertEqual(second, first)
        self.assertEqual(rotated, f"{self.existing},{two}")
        self.assertNotIn(one, rotated)

    def test_rejects_a_wildcard_origin(self):
        with self.assertRaises(ValueError):
            build_api_origins("*", "https://app.example.test")


class LoopbackEndpointTest(unittest.TestCase):
    def test_finds_baked_loopback_urls_in_a_bundle(self):
        bundle = "const api='http://127.0.0.1:8082';const auth='http://localhost:54321';"
        self.assertEqual(
            find_loopback_endpoints(bundle), ["http://127.0.0.1:8082", "http://localhost:54321"]
        )

    def test_reports_nothing_once_the_bundle_is_public(self):
        bundle = "const api='https://api.example.test';const auth='https://auth.example.test';"
        self.assertEqual(find_loopback_endpoints(bundle), [])


class RedirectAllowanceTest(unittest.TestCase):
    config = 'site_url = "https://app.example.test"\nadditional_redirect_urls = ["https://app.example.test/**"]\n'

    def test_reports_no_gap_when_the_tunnel_is_allowed(self):
        self.assertEqual(missing_redirect_allowances(self.config, "https://app.example.test"), [])

    def test_reports_the_url_to_add_when_the_tunnel_rotated(self):
        self.assertEqual(
            missing_redirect_allowances(self.config, "https://app-new.example.test"),
            ["https://app-new.example.test"],
        )


class SharePathsTest(unittest.TestCase):
    def test_uses_a_separate_env_pair_so_the_loopback_gates_keep_working(self):
        paths = share_paths()
        # `make local-preview` and `make verify-local` both refuse non-loopback
        # values in .env.local, so the tunnel must never be written there.
        self.assertNotEqual(paths["frontend"], paths["share_frontend"])
        self.assertNotEqual(paths["api"], paths["share_api"])
        for name in ("frontend", "api"):
            self.assertTrue(paths[name].name.startswith(".env.local"))
            self.assertTrue(paths["share_" + name].name.startswith(".env.share"))


class ShareConfigurationTest(unittest.TestCase):
    def test_shared_api_inherits_model_credentials_from_local_api(self):
        local = {"APP_ENV":"development","PORT":"8082","DATABASE_URL":"postgres://runtime@db/revocred","SUPABASE_URL":"http://127.0.0.1:54321","SUPABASE_ANON_KEY":"public","REQUEST_TIMEOUT":"30s","SHUTDOWN_TIMEOUT":"10s","DB_MAX_CONNS":"10","OPENCODE_GO_API_KEY":"test-only","OPENCODE_GO_MODEL":"configured-model"}
        shared = build_share_api(local, "https://app.example.test")
        self.assertEqual(shared["OPENCODE_GO_API_KEY"], "test-only")
        self.assertEqual(shared["OPENCODE_GO_MODEL"], "configured-model")

    def test_refresh_updates_rotated_urls_and_keeps_unrelated_settings(self):
        import tempfile
        from pathlib import Path
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ".env.share"
            path.write_text("REVOCRED_API_URL=https://old.example.test\nOTHER=keep\n")
            write_env_file(path, {"REVOCRED_API_URL":"https://new.example.test"})
            self.assertEqual(env_file(path)["REVOCRED_API_URL"], "https://new.example.test")
            self.assertEqual(env_file(path)["OTHER"], "keep")
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

if __name__ == "__main__":
    unittest.main()
