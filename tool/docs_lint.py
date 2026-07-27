#!/usr/bin/env python3
"""Machine-checkable claims in the docs.

Only checks things a machine can decide. Semantic drift — a status table that
says "pending" for something already done, a feature list describing an older
version — is the doc-audit agent's job, not this script's.

Run from the repo root:  python3 tool/docs_lint.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# History must stay as it was written, even where it is now wrong: an audit
# records what was true on its date, a shipped spec records what was designed,
# and CHANGELOG entries are immutable once released. Only live documents —
# the READMEs, CLAUDE.md, active plans — are held to current reality.
SKIP_DIRS = {'.git', 'node_modules', 'build', 'dist', '.dart_tool',
             'archive', 'specs'}
SKIP_FILES = {'CHANGELOG.md', 'AUDIT.md'}
SKIP_PATTERNS = ('audit',)

failures: list[str] = []


def docs() -> list[Path]:
    out = []
    for p in ROOT.rglob('*.md'):
        if any(part in SKIP_DIRS for part in p.parts):
            continue
        if p.name in SKIP_FILES:
            continue
        if any(s in p.name.lower() for s in SKIP_PATTERNS):
            continue
        out.append(p)
    return sorted(out)


def check_android_build_commands(paths: list[Path]) -> None:
    """Android is flavor-split; a build without --flavor fails outright.

    Regression guard for the 0.83 channel split, which left both READMEs
    telling people to run a command that could not work.
    """
    cmd = re.compile(r'flutter\s+build\s+(apk|appbundle)\b')
    for p in paths:
        lines = p.read_text(encoding='utf-8').splitlines()
        for n, line in enumerate(lines, 1):
            if not cmd.search(line):
                continue
            # Commands wrap across lines in prose and in shell blocks; judge the
            # whole invocation, not the first line of it.
            window = ' '.join(lines[n - 1:n + 2])
            if '--flavor' not in window:
                failures.append(
                    f'{p.relative_to(ROOT)}:{n}: Android build command without '
                    f'--flavor (it will fail):\n    {line.strip()}')


def check_relative_links(paths: list[Path]) -> None:
    """[text](path) pointing at a file that no longer exists."""
    link = re.compile(r'\[[^\]]*\]\(([^)]+)\)')
    for p in paths:
        for n, line in enumerate(p.read_text(encoding='utf-8').splitlines(), 1):
            for target in link.findall(line):
                target = target.split('#')[0].strip()
                if not target or re.match(r'^(https?:|mailto:|#)', target):
                    continue
                # `palette[](按列交替)` and friends are prose, not links: a real
                # target has no spaces and looks like a path.
                if ' ' in target or not re.search(r'[/.]', target):
                    continue
                resolved = (ROOT if target.startswith('/')
                            else p.parent) / target.lstrip('/')
                if not resolved.exists():
                    failures.append(
                        f'{p.relative_to(ROOT)}:{n}: dead link -> {target}')


def check_changelog_version() -> None:
    """The newest CHANGELOG entry must match pubspec's version."""
    pubspec = (ROOT / 'app/pubspec.yaml').read_text(encoding='utf-8')
    m = re.search(r'^version:\s*(\d+\.\d+\.\d+)', pubspec, re.M)
    if not m:
        failures.append('app/pubspec.yaml: no version line')
        return
    version = m.group(1)

    changelog = (ROOT / 'CHANGELOG.md').read_text(encoding='utf-8')
    top = re.search(r'^## \[v(\d+\.\d+\.\d+)\]', changelog, re.M)
    if not top:
        failures.append('CHANGELOG.md: no version heading')
        return
    if top.group(1) != version:
        failures.append(
            f'CHANGELOG.md: newest entry is v{top.group(1)} but '
            f'app/pubspec.yaml says {version}')


def check_test_count(paths: list[Path]) -> None:
    """Docs quoting a test count must agree with each other.

    The real count comes from `flutter test`; CI passes it in via argv so this
    stays runnable offline. Without it, we only check the docs are consistent.
    """
    actual = None
    if len(sys.argv) > 1 and sys.argv[1].isdigit():
        actual = int(sys.argv[1])

    quoted: dict[str, list[tuple[Path, int]]] = {}
    pat = re.compile(r'(\d{2,4})\s*(?:tests|项测试)')
    for p in paths:
        for n, line in enumerate(p.read_text(encoding='utf-8').splitlines(), 1):
            for count in pat.findall(line):
                quoted.setdefault(count, []).append((p, n))

    if not quoted:
        return
    if actual is not None:
        for count, sites in quoted.items():
            if int(count) != actual:
                for p, n in sites:
                    failures.append(
                        f'{p.relative_to(ROOT)}:{n}: doc says {count} tests, '
                        f'the suite has {actual}')
    elif len(quoted) > 1:
        detail = '; '.join(
            f'{c} ({", ".join(f"{p.relative_to(ROOT)}:{n}" for p, n in s)})'
            for c, s in quoted.items())
        failures.append(f'docs disagree on the test count: {detail}')


def main() -> int:
    paths = docs()
    check_android_build_commands(paths)
    check_relative_links(paths)
    check_changelog_version()
    check_test_count(paths)

    if failures:
        print(f'docs_lint: {len(failures)} problem(s)\n')
        for f in failures:
            print(f'  {f}')
        return 1
    print(f'docs_lint: {len(paths)} files, no problems')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
