"""Check sensitive-data guard behavior using synthetic, in-memory values only."""

from contextlib import redirect_stderr, redirect_stdout
import io
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts/ai"))
import secret_scan


class SensitiveDataGuardTests(unittest.TestCase):
    def test_known_credential_formats_are_detected_without_echoing_values(self):
        examples = {
            "github-token": "gh" + "p_" + "A" * 36,
            "aws-access-key": "AK" + "IA" + "A" * 16,
            "api-token": "s" + "k-" + "B" * 32,
            "private-key": "-----BEGIN " + "PRIVATE KEY-----",
            "credential-in-url": "https://" + "synthetic:placeholder" + "@example.invalid/",
        }
        for rule, example in examples.items():
            with self.subTest(rule=rule):
                findings = secret_scan.inspect("candidate.lua", example.encode())
                self.assertIn(rule, findings)
                self.assertTrue(all(example not in finding for finding in findings))

    def test_private_files_are_rejected_before_any_content_read(self):
        examples = [".env", "nested/.env.local", "key.pem", ".tools/runtime/file.lua", "hub.log"]
        for name in examples:
            with self.subTest(name=name):
                self.assertEqual(secret_scan.inspect(name, b""), ["forbidden-private-file"])
        output = io.StringIO()
        with patch.object(secret_scan, "git", side_effect=[str(ROOT).encode(), b".env\0"]) as git:
            with redirect_stderr(output):
                self.assertEqual(secret_scan.scan(True), 1)
            self.assertEqual(git.call_count, 2)

    def test_staged_content_is_scanned_and_findings_remain_redacted(self):
        example = "gh" + "p_" + "C" * 36
        replies = [str(ROOT).encode(), b"candidate.lua\0", example.encode()]
        output = io.StringIO()
        with patch.object(secret_scan, "git", side_effect=replies) as git:
            with redirect_stderr(output), redirect_stdout(output):
                self.assertEqual(secret_scan.scan(True), 1)
            git.assert_called_with("show", ":candidate.lua")
        self.assertIn("candidate.lua [github-token]", output.getvalue())
        self.assertTrue(example not in output.getvalue(), "matched values must remain redacted")

    def test_normal_source_and_synthetic_examples_are_allowed(self):
        text = b'local address = "192.0.2.10" -- documentation-only address'
        self.assertEqual(secret_scan.inspect("example.lua", text), [])
        self.assertEqual(secret_scan.inspect("README.md", b"Document .env; never commit it."), [])


if __name__ == "__main__":
    unittest.main()
