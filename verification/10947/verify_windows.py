"""Replay the unchanged report using native Windows and Pixi's LLVM 11 build."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys

ROOT = Path.cwd()
LOGS = ROOT / '.fix-issue/10947/windows'
LOGS.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / 'verification/10947/re_issue_10947.f90'
SOURCE_HASH = '873606ecb125cdbce21162981f2d1d54533e77aa0389d45e10007b53b46f79c7'


def require(condition, evidence):
    if not condition:
        raise RuntimeError(str(evidence))


def native_executable(path):
    """Verify the output is an AMD64 PE executable, not a script or mock."""
    data = path.read_bytes()
    require(data[:2] == b'MZ', (path, 'missing DOS header'))
    offset = struct.unpack_from('<I', data, 0x3C)[0]
    require(data[offset:offset + 4] == b'PE\0\0', (path, 'missing PE header'))
    machine = struct.unpack_from('<H', data, offset + 4)[0]
    require(machine == 0x8664, (path, 'not AMD64', machine))
    return {'path': str(path), 'sha256': hashlib.sha256(data).hexdigest(),
            'pe_machine': hex(machine)}


def run(label, argv, check_output=False):
    result = subprocess.run([str(x) for x in argv], cwd=LOGS, text=True,
                            capture_output=True, timeout=180)
    (LOGS / (label + '.stdout')).write_text(result.stdout, encoding='utf-8')
    (LOGS / (label + '.stderr')).write_text(result.stderr, encoding='utf-8')
    evidence = {'label': label, 'argv': [str(x) for x in argv],
                'exit': result.returncode, 'stdout': result.stdout,
                'stderr': result.stderr}
    (LOGS / (label + '.json')).write_text(json.dumps(evidence, indent=2), encoding='utf-8')
    print(json.dumps(evidence), flush=True)
    require(result.returncode == 0, (label, result.returncode))
    if check_output:
        require(result.stdout.split() == ['ab', 'cd', 'ab', 'cd'],
                (label, 'wrong printed values', result.stdout))
        require(len(result.stdout.splitlines()) == 1,
                (label, 'expected one output line', result.stdout))
    return result.stdout


require(sys.platform == 'win32', sys.platform)
require(hashlib.sha256(SOURCE.read_bytes().replace(b'\r\n', b'\n')).hexdigest()
        == SOURCE_HASH, 'original report source changed')
require(os.environ['PIXI_ENVIRONMENT_NAME'] == 'llvm11', 'wrong Pixi environment')
build = Path(os.environ['LFORTRAN_BUILD_DIR']).resolve()
require(build == (ROOT / 'build/llvm11').resolve(), ('wrong build', build))
compiler = build / 'src/bin/lfortran.exe'
require(Path(shutil.which('lfortran')).resolve() == compiler.resolve(),
        ('wrong PATH compiler', shutil.which('lfortran')))
head = run('git-sha', ['git', '-C', ROOT, 'rev-parse', 'HEAD']).strip()
version = run('toolchain', [compiler, '--version'])
require('Platform: Windows' in version, version)
require('LLVM: 11.1.0' in version, version)
require('windows-msvc' in version, version)
require(run('llvm-config', ['llvm-config', '--version']).strip() == '11.1.0',
        'wrong LLVM dependency')
facts = {'head': head, 'source_sha256': SOURCE_HASH, 'platform': sys.platform,
         'compiler': native_executable(compiler),
         'sdk': {key: os.environ.get(key) for key in
                 ['VCToolsInstallDir', 'VCToolsVersion', 'WindowsSdkDir',
                  'WindowsSDKVersion', 'VSCMD_ARG_TGT_ARCH']},
         'executables': []}
require(all(facts['sdk'].values()), ('missing native SDK evidence', facts['sdk']))
require(facts['sdk']['VSCMD_ARG_TGT_ARCH'] == 'x64', facts['sdk'])
run('original-auto', [compiler, SOURCE], check_output=True)
for mode, flags in [('normal', []), ('fast', ['--fast']), ('f23', ['--std=f23'])]:
    executable = LOGS / ('original-' + mode + '.exe')
    run(mode + '-compile', [compiler, *flags, SOURCE, '-o', executable])
    facts['executables'].append(native_executable(executable))
    run(mode + '-run', [executable], check_output=True)
(LOGS / 'evidence.json').write_text(json.dumps(facts, indent=2), encoding='utf-8')
print('WINDOWS_ORIGINAL_10947_VERIFIED', flush=True)
