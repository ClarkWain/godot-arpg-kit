"""Guard the test gate against false passes and process failures."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('runner', Path(__file__).resolve().parents[1] / 'run_tests.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class TestResultGate(unittest.TestCase):
    def test_valid_run(self):
        counts, problems = runner.check_output('combat', '[RESULT] suite=combat passed=67 failed=0 total=67\n', 0)
        self.assertEqual(counts['passed'], 67)
        self.assertEqual(problems, [])

    def test_broken_runs_never_pass(self):
        cases = [
            ('', 0),
            ('[RESULT] suite=items passed=1 failed=0 total=1', 0),
            ('[RESULT] suite=combat passed=0 failed=0 total=0', 0),
            ('[RESULT] suite=combat passed=2 failed=0 total=3', 0),
            ('[RESULT] suite=combat passed=1 failed=1 total=2', 0),
            ('[RESULT] suite=combat passed=1 failed=0 total=1', 1),
            ('[RESULT] suite=combat passed=1 failed=0 total=1\nSCRIPT ERROR: broken', 0),
            ('[RESULT] suite=combat passed=1 failed=0 total=1\nERROR: unexpected', 0),
            ('[RESULT] suite=combat passed=1 failed=0 total=1\nWARNING: ObjectDB instances leaked at exit', 0),
            ('[RESULT] suite=combat passed=1 failed=0 total=1\n' * 2, 0),
        ]
        for output, code in cases:
            with self.subTest(output=output, code=code):
                self.assertTrue(runner.check_output('combat', output, code)[1])

    def test_expected_errors_are_scoped_and_exact(self):
        error = 'ERROR: ItemInstance.create: data 不能为空!'
        summary = '[RESULT] suite=items passed=1 failed=0 total=1\n'
        self.assertFalse(runner.check_output('items', summary + error, 0)[1])
        self.assertTrue(runner.check_output('items', summary + error + ' unexpected', 0)[1])
        self.assertTrue(runner.check_output('combat', summary.replace('items', 'combat') + error, 0)[1])

    def test_timeout_preserves_partial_log_and_fails(self):
        with tempfile.TemporaryDirectory() as folder:
            log = Path(folder) / 'suite.log'
            with patch.object(runner.subprocess, 'run', side_effect=subprocess.TimeoutExpired('godot', 1, output=b'partial')):
                output, code = runner.execute(['godot'], log, 1)
            self.assertEqual(code, 124)
            self.assertIn('partial', log.read_text())
            self.assertTrue(runner.check_output('combat', output, code)[1])

    def test_process_exit_status_is_preserved(self):
        with tempfile.TemporaryDirectory() as folder:
            with patch.object(runner.subprocess, 'run', return_value=subprocess.CompletedProcess('godot', 7, stdout='failure')):
                output, code = runner.execute(['godot'], Path(folder) / 'log', 1)
            self.assertEqual(code, 7)
            self.assertEqual(output, 'failure')


if __name__ == '__main__':
    unittest.main()
