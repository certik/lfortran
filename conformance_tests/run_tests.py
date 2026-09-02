#!/usr/bin/env python3
"""Prototype runner for the Fortran 2023 conformance test suite.

Conventions (see doc/fortran_2023_conformance_tests.md):

  <RULE>_valid.f90     one conforming program per rule exercising all of its
                       facets; must compile and run with exit code 0.
  <RULE>_invalid.f90   one file per rule containing many independent invalid
                       cases, each in its own program unit.  Every offending
                       line carries a marker

                           ! {error <RULE> <case-id>}

                       and the compiler must report an error on that line.
                       Each marker is a separate test case.

  expected_failures.txt  known failures, one per line:  <test-name>  # reason
                       where <test-name> is "<RULE>_valid" or
                       "<RULE>_invalid:<case-id>".  Regenerate with
                       --update-xfail; an entry that passes is reported as
                       XPASS so that the list cannot go stale.

Reference compilers (--reference gfortran --reference flang-new-18) are run
on the same files: a valid file must be accepted and run by them, and each
invalid case should be diagnosed by them.  Reference results never decide
pass/fail for LFortran; they are printed so that a case that only LFortran,
or no compiler, agrees with can be reviewed.
"""
import argparse, glob, os, re, subprocess, sys, collections, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
MARK = re.compile(r'!\s*\{error\s+([RC]\d+)(?:\s+([\w-]+))?\}')
NAME = re.compile(r'^([RC]\d+)_(valid|invalid)\.f(90)?$')
# "--error-format short" prints:  file:L1-L2:C1-C2: <stage> error[ [CODE]]: msg
SHORT = re.compile(r'^(.*?):(\d+)-(\d+):(\d+)-(\d+): (.*?)(?: error| Error)(?: \[([A-Za-z0-9.]+)\])?: (.*)$')
# gfortran:  file:LINE:COL:  followed later by "Error: ..."; flang: file:LINE:COL: error: ...
REF_LOC = re.compile(r'^(?:\./)?(?:.*/)?([\w.]+\.f(?:90)?):(\d+):(\d+)')


def discover(root, pattern):
    tests = []
    for path in sorted(glob.glob(os.path.join(root, '**', '*.f*'), recursive=True)):
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


def cases(path):
    """(line, rule, case-id) for every marker in an invalid file."""
    out = []
    for i, line in enumerate(open(path), start=1):
        m = MARK.search(line)
        if m:
            out.append((i, m.group(1), m.group(2) or f'line{i}'))
    return out


def lfortran_errors(output):
    """{line: [(code, message)]} from LFortran's short error format."""
    found = collections.defaultdict(list)
    for line in output.splitlines():
        m = SHORT.match(line)
        if m and 'warning' not in m.group(6):
            found[int(m.group(2))].append((m.group(7), m.group(8)))
    return found


def unit_ranges(path):
    """[(first, last)] of the top-level program units of a file.  Convention:
    top-level END statements start in column 1 and nothing else does."""
    ranges, start = [], 1
    for i, line in enumerate(open(path), start=1):
        if re.match(r'end\b', line, re.I):
            ranges.append((start, i))
            start = i + 1
    return ranges


def unit_of(line, ranges):
    for a, b in ranges:
        if a <= line <= b:
            return (a, b)
    return (line, line)


def reference_error_lines(compiler, path, std):
    """Set of lines on which a reference compiler reports an error."""
    lines = set()
    with tempfile.TemporaryDirectory() as tmp:
        rc, out = run([compiler, '-fsyntax-only', '-std=' + std, path], tmp)
    pending = None
    for l in out.splitlines():
        m = REF_LOC.match(l)
        if m:
            pending = int(m.group(2))
            if 'error:' in l:            # flang puts the message on the same line
                lines.add(pending)
        elif l.startswith('Error:') and pending is not None:   # gfortran
            lines.add(pending)
            pending = None
    return lines


def check_valid(path, lf, std):
    with tempfile.TemporaryDirectory() as tmp:
        exe = os.path.join(tmp, 'a.out')
        rc, out = run([lf, '--std=' + std, '--no-color', path, '-o', exe], tmp)
        if rc != 0:
            return False, 'does not compile: ' + (out.strip().splitlines() or ['?'])[0][:100]
        rc, out = run([exe], tmp)
        if rc != 0:
            return False, f'runtime exit code {rc}: ' + out.strip()[:80]
    return True, ''


def reference_valid(compiler, path, std):
    with tempfile.TemporaryDirectory() as tmp:
        exe = os.path.join(tmp, 'a.out')
        rc, out = run([compiler, '-std=' + std, path, '-o', exe], tmp)
        if rc != 0:
            return 'rejects'
        rc, out = run([exe], tmp)
        return 'runs' if rc == 0 else f'exit {rc}'


def check_invalid(path, lf, std, codes):
    """Returns {case-id: (passed, note)} plus the number of unattributed errors."""
    with tempfile.TemporaryDirectory() as tmp:
        rc, out = run([lf, '--std=' + std, '--semantics-only', '--continue-compilation',
                       '--no-color', '--error-format', 'short', path], tmp)
    errs = lfortran_errors(out)
    results = {}
    marked = set()
    for line, rule, case in cases(path):
        marked.add(line)
        on_line = errs.get(line, [])
        if not on_line:
            why = 'not detected' + (' (warning only)' if f':{line}-' in out and 'warning' in out else '')
            results[case] = (False, why)
        elif codes and not any(c == rule for c, _ in on_line):
            results[case] = (False, f'detected without code {rule}: {on_line[0][1][:60]}')
        else:
            note = '' if any(c == rule for c, _ in on_line) else 'detected, no rule code'
            results[case] = (True, note)
    extra = sorted(l for l in errs if l not in marked)
    return results, extra


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('-t', '--test', help='substring filter on the file name')
    ap.add_argument('--lfortran', default='lfortran')
    ap.add_argument('--std', default='f23')
    ap.add_argument('--reference', action='append', default=[],
                    help='reference compiler (repeatable), e.g. gfortran, flang-new-18')
    ap.add_argument('--reference-std', default='f2018')
    ap.add_argument('--codes', action='store_true', help='require the rule code in the diagnostic')
    ap.add_argument('--update-xfail', action='store_true')
    ap.add_argument('--coverage', help='path to doc/fortran_2023_rules.txt: print per-rule coverage')
    a = ap.parse_args()

    xfail_path = os.path.join(HERE, 'expected_failures.txt')
    xfail = set()
    if os.path.exists(xfail_path):
        xfail = {l.split('#')[0].strip() for l in open(xfail_path) if l.split('#')[0].strip()}

    results = []   # (name, rule, kind, status, note, refs)
    for path, rule, kind in discover(HERE, a.test):
        base = os.path.basename(path).rsplit('.', 1)[0]
        if kind == 'valid':
            ok, why = check_valid(path, a.lfortran, a.std)
            refs = {r: reference_valid(r, path, a.reference_std) for r in a.reference}
            results.append((base, rule, kind, ok, why, refs))
        else:
            per_case, extra = check_invalid(path, a.lfortran, a.std, a.codes)
            ref_lines = {r: reference_error_lines(r, path, a.reference_std) for r in a.reference}
            ranges = unit_ranges(path)
            for line, _, case in cases(path):
                ok, why = per_case[case]
                lo, hi = unit_of(line, ranges)
                # a reference compiler "rejects" a case if it reports any error
                # inside the case's program unit (it may pick a different line)
                refs = {r: ('rejects' if any(lo <= l <= hi for l in ref_lines[r]) else 'accepts')
                        for r in a.reference}
                results.append((f'{base}:{case}', rule, kind, ok, why, refs))
            if extra:
                print(f'note  {base:28} LFortran also reports errors on unmarked lines {extra}')

    width = max([len(r[0]) for r in results] + [10])
    for name, rule, kind, ok, why, refs in results:
        status = 'PASS' if ok else 'FAIL'
        if name in xfail:
            status = 'XPASS' if ok else 'XFAIL'
        ref = '  '.join(f'{k.split("-")[0]}={v}' for k, v in refs.items())
        print(f'{status:5} {name:{width}}  {ref:34} {why}')

    counts = collections.Counter(
        ('XPASS' if ok else 'XFAIL') if n in xfail else ('PASS' if ok else 'FAIL')
        for n, _, _, ok, _, _ in results)
    print('\n' + ', '.join(f'{k}: {v}' for k, v in sorted(counts.items())))

    if a.reference:
        agree = sum(1 for r in results if r[5] and all(v in ('runs', 'rejects') for v in r[5].values()))
        print(f'reference compilers all agree with the test on {agree}/{len(results)} cases')

    if a.update_xfail:
        with open(xfail_path, 'w') as f:
            for name, rule, kind, ok, why, refs in results:
                if not ok:
                    f.write(f'{name}  # {why}\n')
        print('updated', xfail_path)

    if a.coverage:
        rules = list(dict.fromkeys(re.findall(r'^([RC]\d+)\b', open(a.coverage).read(), re.M)))
        per = collections.defaultdict(collections.Counter)
        for name, rule, kind, ok, why, refs in results:
            per[rule][kind] += 1
            per[rule][kind + '_pass'] += ok
        both = [r for r in rules if r in per and per[r]['valid'] and per[r]['invalid']]
        print(f'\ncoverage: {len(both)}/{len(rules)} rules have both a valid and an invalid file')
        for r in rules:
            if r in per:
                c = per[r]
                print(f"  {r:7} valid {c['valid_pass']}/{c['valid']}   invalid cases detected {c['invalid_pass']}/{c['invalid']}")

    sys.exit(1 if any((not ok and n not in xfail) or (ok and n in xfail)
                      for n, _, _, ok, _, _ in results) else 0)


if __name__ == '__main__':
    main()
