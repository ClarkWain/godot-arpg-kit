#!/usr/bin/env python3
"""Run the documented Godot scenes with consistent local and CI results."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SUITES = {
    'combat': 'tests/combat/combat_test_scene.tscn',
    'items': 'tests/items/item_system_test_scene.tscn',
    'loot': 'tests/loot/loot_system_test_scene.tscn',
    'quest': 'tests/quest/test_scene.tscn',
    'stats': 'tests/stats/test_scene.tscn',
}
# These exact errors are intentionally exercised by negative tests.
EXPECTED_ERRORS = {
    'items': {'ERROR: ItemInstance.create: data 不能为空!'},
    'quest': {'ERROR: TaskData: task_id is empty'},
}
RESULT = re.compile(r'^\[RESULT\] suite=(\w+) passed=(\d+) failed=(\d+) total=(\d+)\s*$', re.M)


def check_output(suite, output, exit_code):
    """Require a completed, nonempty run, clean exit, and no unexpected errors."""
    problems = []
    matches = RESULT.findall(output)
    counts = None
    if len(matches) != 1 or matches[0][0] != suite:
        problems.append('missing, duplicate or mismatched [RESULT] summary')
    else:
        _, passed, failed, total = matches[0]
        counts = dict(passed=int(passed), failed=int(failed), total=int(total))
        if counts['total'] <= 0 or counts['passed'] + counts['failed'] != counts['total']:
            problems.append('empty or inconsistent test counts')
        if counts['failed'] or counts['passed'] != counts['total']:
            problems.append('test assertions failed')
    if exit_code != 0:
        problems.append(f'Godot exited with status {exit_code}')
    for line in output.splitlines():
        line = line.strip()
        if ('SCRIPT ERROR:' in line or 'ERROR:' in line) and line not in EXPECTED_ERRORS.get(suite, set()):
            problems.append(line)
        elif 'leaked' in line or 'resources still in use' in line:
            problems.append(line)
    return counts, problems


def execute(command, log_path, timeout):
    try:
        process = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, text=True,
                                 encoding='utf-8', errors='replace', timeout=timeout)
        output, code = process.stdout, process.returncode
    except subprocess.TimeoutExpired as error:
        output = error.stdout or ''
        if isinstance(output, bytes):
            output = output.decode('utf-8', errors='replace')
        output += f'\nERROR: timed out after {timeout} seconds\n'
        code = 124
    log_path.write_text(output, encoding='utf-8')
    return output, code


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--only', choices=SUITES, help='run a single module')
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--timeout', type=float, default=120, help='seconds per import or suite')
    parser.add_argument('--output-dir', type=Path, default=ROOT / '.godot' / 'test-results')
    args = parser.parse_args(argv)
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    godot = shutil.which(args.godot)
    if not godot:
        parser.error('Godot not found; set GODOT or pass --godot')
    args.output_dir.mkdir(parents=True, exist_ok=True)
    run_dir = Path(tempfile.mkdtemp(prefix='run-', dir=args.output_dir))
    print(f'Godot: {godot}\nProject: {ROOT}\nLogs: {run_dir}', flush=True)
    output, code = execute([godot, '--headless', '--path', str(ROOT), '--editor', '--import'],
                           run_dir / 'import.log', args.timeout)
    import_errors = code != 0 or 'ERROR:' in output
    if import_errors:
        print(output)
        print(f'Import failed (exit={code}); suites were not run.', file=sys.stderr)
        return 1
    results = []
    for suite, scene in SUITES.items():
        if args.only and suite != args.only:
            continue
        output, code = execute([godot, '--headless', '--path', str(ROOT), 'res://' + scene],
                               run_dir / f'{suite}.log', args.timeout)
        counts, problems = check_output(suite, output, code)
        results.append(dict(suite=suite, exit_code=code, counts=counts, problems=problems))
        print(f'{suite}: {counts} exit={code} ' + ('FAIL' if problems else 'PASS'), flush=True)
        if problems:
            print(output)
            for problem in problems:
                print(f'  {problem}', file=sys.stderr)
    summary = dict(results=results,
                   passed=sum(r['counts']['passed'] for r in results if r['counts']),
                   failed=sum(r['counts']['failed'] for r in results if r['counts']),
                   ok=bool(results) and all(not r['problems'] for r in results))
    (run_dir / 'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f"Total: {summary['passed']} passed / {summary['failed']} failed; summary: {run_dir / 'summary.json'}")
    return 0 if summary['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
