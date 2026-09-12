#!/usr/bin/env python3
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INSTALL = ROOT / "scripts" / "chef360" / "install-server.sh"


class InstallServerTests(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.work = Path(self.tempdir.name)
        self.installer = self.work / "chef-360"
        self.license = self.work / "license.yaml"
        self.args_log = self.work / "args.log"
        self.installer.write_text(f'#!/usr/bin/env bash\nprintf "%s\\n" "$@" > "{self.args_log}"\n')
        self.installer.chmod(0o700)
        self.license.write_text("license")

    def tearDown(self):
        self.tempdir.cleanup()

    def run_install(self, *args, password="password-123", **env):
        environment = os.environ | {"CHEF360_ADMIN_CONSOLE_PASSWORD": password} | env
        return subprocess.run(
            [str(INSTALL), "--installer", str(self.installer), "--license", str(self.license), "--skip-host-check", *args],
            text=True,
            capture_output=True,
            env=environment,
            check=False,
        )

    def test_base_install_uses_only_required_arguments(self):
        result = self.run_install("--hostname", "chef360.demo.lab")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.args_log.read_text().splitlines(),
            ["install", "--license", str(self.license), "--admin-console-password", "password-123", "--yes", "--hostname", "chef360.demo.lab"],
        )
        self.assertNotIn("password-123", result.stdout)

    def test_config_and_tls_are_optional_arguments(self):
        config = self.work / "config.yaml"
        cert = self.work / "cert.crt"
        key = self.work / "key.key"
        config.write_text("kind: ConfigValues\nmetadata:\n  name: chef-360\n")
        cert.write_text("cert")
        key.write_text("key")
        result = self.run_install("--config-values", str(config), "--tls-cert", str(cert), "--tls-key", str(key))
        self.assertEqual(result.returncode, 0, result.stderr)
        arguments = self.args_log.read_text().splitlines()
        self.assertIn("--config-values", arguments)
        self.assertIn("--tls-cert", arguments)
        self.assertIn("--tls-key", arguments)

    def test_rejects_partial_tls_pair(self):
        cert = self.work / "cert.crt"
        cert.write_text("cert")
        result = self.run_install("--tls-cert", str(cert))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("both --tls-cert and --tls-key", result.stderr)

    def test_rejects_short_noninteractive_password(self):
        result = self.run_install(password="short")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("must contain at least 12 characters", result.stderr)
        self.assertFalse(self.args_log.exists())


if __name__ == "__main__":
    unittest.main()
