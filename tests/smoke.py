#!/usr/bin/env python3
"""Small dependency-free regression check for operator-kit."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AGENTS = {
    "echo": {"Read", "Grep", "Glob"},
    "hypatia": {"Read", "Grep", "Glob"},
    "iris": {"Read", "Grep", "Glob"},
    "lyra": {"Read", "Grep", "Glob", "Edit", "Write", "Bash"},
    "newton": {"Read", "Grep", "Glob", "WebSearch", "WebFetch"},
}


def run(*args: str, cwd: Path | None = None, env: dict[str, str] | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=cwd or ROOT,
        env=env,
        check=check,
        text=True,
        capture_output=True,
    )


def frontmatter(path: Path) -> dict[str, str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    assert lines and lines[0] == "---", f"missing frontmatter: {path}"
    data: dict[str, str] = {}
    for line in lines[1:]:
        if line == "---":
            break
        key, separator, value = line.partition(":")
        assert separator, f"invalid frontmatter line in {path}: {line}"
        data[key.strip()] = value.strip().strip('"')
    return data


def test_agents() -> None:
    files = sorted((ROOT / "agents").glob("*.md"))
    assert len(files) == 5, files
    found: set[str] = set()
    for path in files:
        data = frontmatter(path)
        name = data["name"]
        assert name == name.lower() and name.replace("-", "").isalnum(), name
        assert name not in found, name
        found.add(name)
        assert data.get("model") in {"haiku", "sonnet"}
        tools = {tool.strip() for tool in data["tools"].split(",")}
        assert tools == AGENTS[name], (name, tools)
        assert "*" not in tools
    assert found == set(AGENTS)


def test_static_files() -> None:
    run("bash", "-n", str(ROOT / "install.sh"))
    run("bash", "-n", str(ROOT / "context-loader" / "auto-context-load.sh"))
    for path in [
        ROOT / ".claude-plugin" / "plugin.json",
        ROOT / ".claude-plugin" / "marketplace.json",
        ROOT / "hooks" / "hooks.json",
        ROOT / "context-loader" / "project-keywords.json",
        ROOT / "examples" / "sample-project-keywords.json",
    ]:
        json.loads(path.read_text(encoding="utf-8"))

    plugin = json.loads((ROOT / ".claude-plugin" / "plugin.json").read_text())
    assert plugin["name"] == "operator-kit"
    assert plugin["version"] == "2.1.0"

    hooks = json.loads((ROOT / "hooks" / "hooks.json").read_text())
    hook = hooks["hooks"]["UserPromptSubmit"][0]["hooks"][0]
    assert hook == {
        "type": "command",
        "command": "bash",
        "args": ["${CLAUDE_PLUGIN_ROOT}/context-loader/auto-context-load.sh"],
    }


def loader(project: Path, prompt: str, *, home: Path, debug: bool = False) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["HOME"] = str(home)
    env["PROJECT_ROOT"] = str(project)
    if debug:
        env["OPERATOR_KIT_DEBUG"] = "1"
    else:
        env.pop("OPERATOR_KIT_DEBUG", None)
    payload = json.dumps({"hook_event_name": "UserPromptSubmit", "cwd": str(project), "prompt": prompt})
    return subprocess.run(
        ["bash", str(ROOT / "context-loader" / "auto-context-load.sh")],
        input=payload,
        text=True,
        capture_output=True,
        env=env,
        check=True,
    )


def test_context_loader() -> None:
    with tempfile.TemporaryDirectory(prefix="operator-kit-auth-service-") as tmp:
        base = Path(tmp)
        project = base / "auth-service"
        home = base / "home"
        (project / ".claude").mkdir(parents=True)
        (project / "docs").mkdir()
        (project / "docs" / "auth.md").write_text("# Auth\n\nSession rules.\n", encoding="utf-8")
        (base / "secret.txt").write_text("DO NOT SURFACE\n", encoding="utf-8")
        mapping = {
            "auth": {
                "keywords": ["auth", "auth flow"],
                "priority_file": "docs/auth.md",
                "files": ["docs/auth.md", "src/session.ts"],
            },
            "escape": {
                "keywords": ["escape check"],
                "priority_file": "../secret.txt",
                "files": ["../secret.txt"],
            },
        }
        (project / ".claude" / "operator-kit-keywords.json").write_text(
            json.dumps(mapping), encoding="utf-8"
        )

        no_match = loader(project, "hello", home=home)
        assert no_match.stdout == ""
        assert not (project / "memory").exists()
        assert not (home / ".claude" / "logs").exists()

        boundary = loader(project, "reauthenticate this user", home=home)
        assert boundary.stdout == ""

        match = loader(project, "review the auth flow", home=home)
        assert '<operator-kit-context topic="auth">' in match.stdout
        assert "Session rules." in match.stdout
        assert "src/session.ts (not found)" in match.stdout
        assert len(match.stdout.encode("utf-8")) <= 80 * 1024
        assert len(match.stdout.splitlines()) <= 3_000

        escape = loader(project, "run the escape check", home=home)
        assert "rejected: outside project root" in escape.stdout
        assert "DO NOT SURFACE" not in escape.stdout

        debug = loader(project, "auth", home=home, debug=True)
        assert debug.stdout
        log = home / ".claude" / "logs" / "operator-kit" / "context-loader.log"
        assert log.is_file()
        assert "auth" in log.read_text(encoding="utf-8")
        assert "review the auth flow" not in log.read_text(encoding="utf-8")


def installer_env(home: Path) -> dict[str, str]:
    env = os.environ.copy()
    env["HOME"] = str(home)
    env["OPERATOR_KIT_INSTALL_RULES"] = "0"
    return env


def test_installer_invalid_settings() -> None:
    with tempfile.TemporaryDirectory(prefix="operator-kit-invalid-") as tmp:
        base = Path(tmp)
        home = base / "home"
        project = base / "project"
        (home / ".claude").mkdir(parents=True)
        project.mkdir()
        settings = home / ".claude" / "settings.json"
        original = b'{"hooks":'
        settings.write_bytes(original)

        result = run(
            "bash",
            str(ROOT / "install.sh"),
            cwd=project,
            env=installer_env(home),
            check=False,
        )
        assert result.returncode != 0
        assert settings.read_bytes() == original
        assert not (home / ".claude" / "agents" / "operator-kit").exists()


def test_installer_idempotency_and_migration() -> None:
    with tempfile.TemporaryDirectory(prefix="operator-kit-install-") as tmp:
        base = Path(tmp)
        home = base / "home with spaces"
        project = base / "project"
        (home / ".claude" / "hooks").mkdir(parents=True)
        project.mkdir()
        settings = home / ".claude" / "settings.json"
        legacy_path = home / ".claude" / "hooks" / "auto-context-load.sh"
        settings.write_text(
            json.dumps(
                {
                    "theme": "dark",
                    "hooks": {
                        "UserPromptSubmit": [
                            {
                                "matcher": "*",
                                "hooks": [
                                    {"type": "command", "command": f"bash {legacy_path}"},
                                    {"type": "command", "command": "echo keep-me"},
                                ],
                            }
                        ]
                    },
                }
            ),
            encoding="utf-8",
        )
        legacy_keywords = home / ".claude" / "hooks" / "operator-kit-keywords.json"
        legacy_keywords.write_text('{"legacy": {"keywords": ["legacy"]}}\n', encoding="utf-8")

        env = installer_env(home)
        first = run("bash", str(ROOT / "install.sh"), cwd=project, env=env)
        assert "Installation complete" in first.stdout
        second = run("bash", str(ROOT / "install.sh"), cwd=project, env=env)
        assert "Hook already wired" in second.stdout

        data = json.loads(settings.read_text(encoding="utf-8"))
        assert data["theme"] == "dark"
        entries = data["hooks"]["UserPromptSubmit"]
        operator_hooks = []
        other_hooks = []
        for entry in entries:
            for hook in entry.get("hooks", []):
                if hook.get("command") == "bash" and hook.get("args"):
                    operator_hooks.append(hook)
                else:
                    other_hooks.append(hook)
        assert len(operator_hooks) == 1, operator_hooks
        expected_hook = home / ".claude" / "hooks" / "operator-kit" / "auto-context-load.sh"
        assert operator_hooks[0]["args"] == [str(expected_hook)]
        assert {hook.get("command") for hook in other_hooks} == {"echo keep-me"}
        assert (home / ".claude" / "operator-kit-keywords.json").read_text() == legacy_keywords.read_text()
        assert len(list((home / ".claude").glob("settings.json.backup-*"))) == 1
        assert not list((home / ".claude" / "hooks").glob("operator-kit.backup-*"))

        installed_agents = sorted((home / ".claude" / "agents" / "operator-kit").glob("*.md"))
        assert len(installed_agents) == 5


def main() -> int:
    tests = [
        test_agents,
        test_static_files,
        test_context_loader,
        test_installer_invalid_settings,
        test_installer_idempotency_and_migration,
    ]
    for test in tests:
        test()
        print(f"ok - {test.__name__}")
    print(f"{len(tests)} checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
