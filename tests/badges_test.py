#!/usr/bin/env python3
"""Exercise badge freshness and failure reporting without a hub or network."""

import importlib.util
import io
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts/testing"))
SPEC = importlib.util.spec_from_file_location(
    "coverage_runner", ROOT / "scripts/testing/coverage.py"
)
coverage = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(coverage)


class BadgeTests(unittest.TestCase):
    def setUp(self):
        (ROOT / ".tools").mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix="badge-tests-", dir=ROOT / ".tools")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.runtime = self.root / ".tools/luacov"
        self.output = self.root / ".tools/coverage"
        (self.runtime / "src").mkdir(parents=True)
        (self.runtime / "src/luacov.lua").write_text("-- synthetic dependency\n")
        (self.root / "tthblock.lua").write_text("-- synthetic script\nreturn true\n")
        (self.root / "tests").mkdir()
        (self.root / "tests/tthblock_test.lua").write_text("-- synthetic suite\n")
        (self.root / ".luacov").write_text("-- synthetic coverage configuration\n")
        values = (("ROOT", self.root), ("RUNTIME", self.runtime), ("OUTPUT", self.output))
        for name, value in values:
            context = patch.object(coverage, name, value)
            context.start()
            self.addCleanup(context.stop)

    def run_measurement(self, report="tthblock.lua 2 0 100.00%\n", code=0, summary=None):
        def run(*args, **kwargs):
            if report is not None:
                (self.output / "luacov.report.out").write_text(report)
            text = summary
            if text is None:
                text = "Passed 33 offline callback tests on Lua 5.4\n"
            return subprocess.CompletedProcess(args[0], code, stdout=text)

        with patch.object(coverage.subprocess, "run", side_effect=run):
            return self.measure()

    def measure(self):
        with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            return coverage.measure("synthetic-lua")

    def badge(self, name):
        path = self.root / "docs/badges" / (name + ".svg")
        self.assertTrue(path.is_file(), "The command must write a badge for its current result")
        return path.read_text()

    def test_success_generates_valid_svg_and_same_inputs_are_deterministic(self):
        self.assertEqual(self.run_measurement(), 0)
        tests, measured = self.badge("tests"), self.badge("coverage")
        self.assertIn("33 passed", tests)
        self.assertIn("100%", measured)
        self.assertIn("Lua 5.4", tests)
        for text in (tests, measured):
            ET.fromstring(text)
        self.assertEqual(self.run_measurement(), 0)
        self.assertEqual(self.badge("tests"), tests)
        self.assertEqual(self.badge("coverage"), measured)
        source = self.root / "tthblock.lua"
        source.write_text(source.read_text() + "-- changed synthetic input\n")
        self.assertEqual(self.run_measurement(), 0)
        self.assertNotEqual(self.badge("tests"), tests)

    def test_failed_suite_replaces_previous_passing_badges(self):
        self.assertEqual(self.run_measurement(), 0)
        self.assertEqual(self.run_measurement(code=1, summary="FAIL synthetic test\n"), 1)
        self.assertIn("failed", self.badge("tests"))
        self.assertIn("not measured", self.badge("coverage"))
        self.assertNotIn("100%", self.badge("coverage"))

    def test_partial_coverage_records_measurement_and_fails_the_gate(self):
        self.assertEqual(self.run_measurement(report="tthblock.lua 1 1 50.00%\n"), 1)
        self.assertIn("33 passed", self.badge("tests"))
        self.assertIn("50%", self.badge("coverage"))
        self.assertNotIn("100%", self.badge("coverage"))

    def test_missing_report_clears_old_coverage(self):
        self.assertEqual(self.run_measurement(), 0)
        self.assertEqual(self.run_measurement(report=None), 1)
        self.assertIn("error", self.badge("coverage"))
        self.assertNotIn("100%", self.badge("coverage"))

    def test_malformed_report_does_not_claim_measured_coverage(self):
        self.assertEqual(self.run_measurement(report="synthetic incomplete report\n"), 1)
        self.assertIn("error", self.badge("coverage"))

    def test_empty_measurement_and_rounding_cannot_fabricate_full_coverage(self):
        self.assertEqual(self.run_measurement(report="tthblock.lua 0 0 100.00%\n"), 1)
        self.assertIn("error", self.badge("coverage"))
        self.assertEqual(self.run_measurement(report="tthblock.lua 99999 1 100.00%\n"), 1)
        self.assertIn("99.99%", self.badge("coverage"))
        self.assertNotIn("100%", self.badge("coverage"))

    def test_interpreter_launch_failure_clears_previous_success(self):
        self.assertEqual(self.run_measurement(), 0)
        with patch.object(coverage.subprocess, "run", side_effect=FileNotFoundError):
            with self.assertRaises(FileNotFoundError):
                self.measure()
        self.assertIn("error", self.badge("tests"))
        self.assertIn("not measured", self.badge("coverage"))

    def test_missing_dependency_and_empty_suite_do_not_claim_success(self):
        empty = "Passed 0 offline callback tests on Lua 5.4"
        self.assertEqual(self.run_measurement(summary=empty), 1)
        self.assertIn("error", self.badge("tests"))
        (self.runtime / "src/luacov.lua").unlink()
        with patch.object(coverage.subprocess, "run") as run:
            self.assertEqual(self.measure(), 1)
            run.assert_not_called()
        self.assertIn("error", self.badge("tests"))

    def test_badge_output_cannot_follow_a_symlink(self):
        self.assertEqual(self.run_measurement(), 0)
        target = self.root / "untouched.svg"
        target.write_text("synthetic original\n")
        badge = self.root / "docs/badges/tests.svg"
        badge.unlink()
        badge.symlink_to(target)
        with self.assertRaises(ValueError):
            self.run_measurement()
        self.assertEqual(target.read_text(), "synthetic original\n")


if __name__ == "__main__":
    unittest.main()
