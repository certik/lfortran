"""Temporary diagnostic artifact: retain the executed ELF and its actual inputs."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tarfile

root = Path.cwd()
output = root / ".fix-issue/pr-16329/ci-llvm11-unit"
exe = root / "lfortran-src/test-bld/src/lfortran/tests/test_lfortran"
ldd = subprocess.check_output(["ldd", str(exe)], text=True)
paths = {exe}
for line in ldd.splitlines():
    match = re.search(r"(?:=>\s+)?(/[^\s]+)\s+\(", line)
    if match:
        paths.add(Path(match[1]))
for pattern in (
    "lfortran-src/test-bld/src/runtime/*.mod",
    "lfortran-src/test-bld/src/lfortran/tests/libplain.a",
    "lfortran-src/src/lfortran/tests/*",
    "lfortran-src/src/tests/*",
):
    paths.update(path for path in root.glob(pattern) if path.is_file())

manifest = []
with tarfile.open(output / "replay.tar.gz", "w:gz", dereference=True) as archive:
    for path in sorted(paths):
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        name = "root/" + str(path).lstrip("/")
        archive.add(path, arcname=name, recursive=False)
        manifest.append({"path": str(path), "archive": name, "sha256": digest,
                         "size": path.stat().st_size})
(output / "replay-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("REPLAY_ELF_SHA256", hashlib.sha256(exe.read_bytes()).hexdigest())
print("REPLAY_FILES", len(manifest))
print("REPLAY_SIZE", (output / "replay.tar.gz").stat().st_size)
