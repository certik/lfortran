#!/usr/bin/env python3
"""Prototype runner for the Fortran 2023 conformance test suite.

Conventions (see doc/fortran_2023_conformance_tests.md):

  <RULE>_ok_<n>.f90    valid program: must compile and run with exit code 0
  <RULE>_bad_<n>.f90   invalid program: must fail to compile; every line that
                       carries a "! {error RULE}" marker must receive an error,
                       and (in strict mode) no other line may receive one.

  expected_failures.txt  one test name per line: tests known to fail on
                       LFortran today (xfail).  An xfail that passes is
                       reported as an unexpected pass so the list can be
                       pruned with --update-xfail.
"""
import argparse, glob, os, re, subprocess, sys, collections, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
MARK = re.compile(r'!\s*\{error(?:\s+([RC]\d+))?\}')
NAME = re.compile(r'^([RC]\d+)_(ok|bad)_(\d+)\.f90$')
# "--error-format short" prints:  file:L1-L2:C1-C2: <stage> error[ [CODE]]: msg
SHORT = re.compile(r'^(.*?):(\d+)-(\d+):(\d+)-(\d+): (.*?)(?: error| Error)(?: \[([A-Z]\d+)\])?: (.*)$')


def discover(root, pattern):
    tests = []
    for path in sorted(glob.glob(os.path.join(root, '**', '*.f90'), recursive=True)):
        m = NAME.match(os.path.basename(path))
        if not m:
            continue
        if pattern and pattern not in os.path.basename(path):
            continue
        tests.append((path, m.group(1), m.group(2)))
    return tests


def run(cmd, cwd):
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def expected_errors(path):
    exp = []
    for i, line in enumerate(open(path), start=1):
        m = MARK.search(line)
        if m:
            exp.append((i, m.group(1)))
    return exp


def parse_errors(output):
    found = []
    for line in output.splitlines():
        m = SHORT.match(line)
        if m and 'warning' not in m.group(6):
            found.append((int(m.group(2)), m.group(7), m.group(8)))
    return found


def check_bad(path, lf, std, strict, codes):
    exp = expected_errors(path)
    if not exp:
        return False, 'no "! {error ...}" marker in an invalid test'
    with tempfile.TemporaryDirectory() as tmp:
        rc, out = run([lf, '--std=' + std, '--semantics-only', '--no-color',
                       '--error-format', 'short', path], tmp)
    errs = parse_errors(out)
    if rc == 0:
        return False, 'compiled without error' + (' (warnings only)' if 'warning' in out else '')
    if not errs:
        # crash or unparsable diagnostic: still a failure of the test
        return False, 'non-zero exit but no parsable error: ' + out.strip().splitlines()[0][:100]
    got_lines = {e[0] for e in errs}
    for line, code in exp:
        if line not in got_lines:
            return False, f'no error reported on line {line} (errors on {sorted(got_lines)})'
        if codes and code and not any(e[1] == code for e in errs if e[0] == line):
            codes = [e[1] or '-' for e in errs if e[0] == line]
            return False, f'line {line}: expected code {code}, reported {codes} ({errs[0][2][:60]})'
    if strict:
        extra = sorted(got_lines - {l for l, _ in exp})
        if extra:
            return False, f'unexpected extra errors on lines {extra}'
    note = '' if all(e[1] for e in errs) else 'detected, but without a rule code'
    return True, note


def check_ok(path, lf, std, reference, ref_std):
    # compile and run in a scratch directory so that .mod files and the
    # executable never land in the source tree
    with tempfile.TemporaryDirectory() as tmp:
        exe = os.path.join(tmp, 'a.out')
        rc, out = run([lf, '--std=' + std, '--no-color', path, '-o', exe], tmp)
        if rc != 0:
            return False, 'does not compile: ' + (out.strip().splitlines() or ['?'])[0][:100]
        rc, out = run([exe], tmp)
        if rc != 0:
            return False, f'runtime exit code {rc}: ' + out.strip()[:80]
        if reference:
            rc, out = run([reference, '-std=' + ref_std, path, '-o', exe], tmp)
            if rc != 0:
                return False, f'{reference} rejects it: ' + (out.strip().splitlines() or ['?'])[-1][:100]
            rc, out = run([exe], tmp)
            if rc != 0:
                return False, f'{reference} binary exits {rc}'
    return True, ''


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('-t', '--test', help='substring filter on the test file name')
    ap.add_argument('--lfortran', default='lfortran')
    ap.add_argument('--std', default='f23')
    ap.add_argument('--reference', help='reference compiler for valid tests, e.g. gfortran')
    ap.add_argument('--reference-std', default='f2018', help='-std= value for the reference compiler')
    ap.add_argument('--no-strict', action='store_true', help='allow extra errors on unmarked lines')
    ap.add_argument('--codes', action='store_true', help='require the rule code in the diagnostic')
    ap.add_argument('--update-xfail', action='store_true')
    ap.add_argument('--coverage', help='path to doc/fortran_2023_rules.txt: print per-rule coverage')
    a = ap.parse_args()

    xfail_path = os.path.join(HERE, 'expected_failures.txt')
    xfail = set()
    if os.path.exists(xfail_path):
        xfail = {l.split('#')[0].strip() for l in open(xfail_path) if l.split('#')[0].strip()}

    results = []
    for path, rule, kind in discover(HERE, a.test):
        name = os.path.basename(path)[:-4]
        if kind == 'bad':
            ok, why = check_bad(path, a.lfortran, a.std, not a.no_strict, a.codes)
        else:
            ok, why = check_ok(path, a.lfortran, a.std, a.reference, a.reference_std)
        status = ('PASS' if ok else 'FAIL')
        if name in xfail:
            status = 'XPASS' if ok else 'XFAIL'
        results.append((name, rule, kind, status, why))
        print(f'{status:5} {name:24} {why}')

    counts = collections.Counter(r[3] for r in results)
    print('\n' + ', '.join(f'{k}: {v}' for k, v in sorted(counts.items())))

    if a.update_xfail:
        with open(xfail_path, 'w') as f:
            for name, rule, kind, status, why in results:
                if status in ('FAIL', 'XFAIL'):
                    f.write(f'{name}  # {why}\n')
        print('updated', xfail_path)

    if a.coverage:
        rules = re.findall(r'^([RC]\d+)\b', open(a.coverage).read(), re.M)
        rules = list(dict.fromkeys(rules))
        per = collections.defaultdict(lambda: collections.Counter())
        for name, rule, kind, status, why in results:
            per[rule][kind] += 1
            per[rule][kind + '_' + status] += 1
        covered = [r for r in rules if r in per and per[r]['ok'] and per[r]['bad']]
        print(f'\ncoverage: {len(covered)}/{len(rules)} rules have both valid and invalid tests')
        print(f'{"rule":8} {"ok":>3} {"bad":>4}  lfortran')
        for r in rules:
            if r in per:
                c = per[r]
                st = f"{c['ok_PASS']}/{c['ok']} valid, {c['bad_PASS']}/{c['bad']} invalid detected"
                print(f'{r:8} {c["ok"]:3} {c["bad"]:4}  {st}')

    sys.exit(1 if any(r[3] in ('FAIL', 'XPASS') for r in results) else 0)


if __name__ == '__main__':
    main()
