#!/usr/bin/env python3
"""Generate codebase audit artifacts from the current worktree.

The script intentionally uses lightweight static analysis. It produces an
exhaustive inventory first, then derived maps and refactor candidates that must
be reviewed by a human before implementation.
"""

from __future__ import annotations

import collections
import datetime as dt
import os
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "audits"


def run(args: list[str]) -> str:
    return subprocess.check_output(args, cwd=ROOT, text=True)


def tracked_and_untracked_files() -> list[str]:
    tracked = run(["git", "ls-files"]).splitlines()
    untracked = run(["git", "ls-files", "--others", "--exclude-standard"]).splitlines()
    return sorted(
        path for path in set(tracked + untracked) if (ROOT / path).is_file()
    )


def resource_views_shared() -> bool:
    task_views = ROOT / "apps/server/src/scrumbringer_server/http/task_views.gleam"
    card_views = ROOT / "apps/server/src/scrumbringer_server/http/card_views.gleam"
    shared = ROOT / "apps/server/src/scrumbringer_server/http/resource_views.gleam"
    if not task_views.exists() or not card_views.exists() or not shared.exists():
        return False

    task_text = task_views.read_text(encoding="utf-8")
    card_text = card_views.read_text(encoding="utf-8")
    return "scrumbringer_server/http/resource_views" in task_text and "scrumbringer_server/http/resource_views" in card_text


def is_excluded(path: str) -> bool:
    parts = path.split("/")
    excluded_parts = {
        ".git",
        ".tmp",
        "build",
        "dist",
        ".lustre",
        "node_modules",
    }
    if any(part in excluded_parts for part in parts):
        return True
    if path.endswith("erl_crash.dump"):
        return True
    return False


def in_scope(path: str) -> bool:
    if is_excluded(path):
        return False
    if path.startswith(("apps/client/src/", "apps/client/test/")):
        return True
    if path.startswith(("apps/server/src/", "apps/server/test/")):
        return True
    if path.startswith(("shared/src/", "shared/test/")):
        return True
    if path.startswith(("docs/", "scripts/", "db/", "deploy/", ".github/")):
        return True
    if path in {
        "Makefile",
        "database.yml",
        "docker-compose.yml",
        "Caddyfile.example",
        "Caddyfile.prod",
        "Caddyfile.smoke",
        "DESIGN.md",
        "PRODUCT.md",
        ".gitignore",
    }:
        return True
    if path.endswith((".toml", ".yml", ".yaml", ".sh", ".sql", ".mjs", ".md")):
        return True
    return False


def read_text(path: str) -> str:
    full = ROOT / path
    try:
        return full.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return ""


def module_name(path: str) -> str:
    stem = path[:-6] if path.endswith(".gleam") else path
    roots = [
        ("apps/client/src/", ""),
        ("apps/client/test/", "test/"),
        ("apps/server/src/", ""),
        ("apps/server/test/", "test/"),
        ("shared/src/", ""),
        ("shared/test/", "test/"),
    ]
    for prefix, replacement in roots:
        if stem.startswith(prefix):
            return replacement + stem[len(prefix) :]
    return stem


def package_for(path: str) -> str:
    if path.startswith("apps/client/"):
        return "client"
    if path.startswith("apps/server/"):
        return "server"
    if path.startswith("shared/"):
        return "shared"
    if path.startswith("docs/"):
        return "docs"
    if path.startswith("scripts/"):
        return "script"
    if path.startswith("db/"):
        return "database"
    if path.startswith("deploy/"):
        return "deploy"
    if path.startswith(".github/"):
        return "ci"
    return "root"


def layer_for(path: str) -> str:
    if "/test/" in path or path.endswith("_test.gleam"):
        return "test"
    if path.startswith("apps/client/"):
        return "frontend"
    if path.startswith("apps/server/"):
        return "backend"
    if path.startswith("shared/"):
        return "shared_domain"
    if path.startswith("docs/"):
        return "docs"
    if path.startswith("scripts/"):
        return "script"
    if path.startswith(("db/", "deploy/", ".github/")):
        return "support"
    if path.endswith((".toml", ".yml", ".yaml")):
        return "config"
    return "support"


def domain_for(path: str) -> str:
    parts = path.split("/")
    known = [
        "auth",
        "cards",
        "card",
        "tasks",
        "task",
        "capabilities",
        "capability",
        "projects",
        "project",
        "workflows",
        "workflow",
        "rules",
        "rule",
        "metrics",
        "org",
        "people",
        "members",
        "invites",
        "api_tokens",
        "activity",
        "notes",
        "layout",
        "pool",
        "plan",
        "admin",
        "automations",
        "assignments",
        "i18n",
    ]
    lowered = path.lower().replace("-", "_")
    for item in known:
        if item in parts or item in lowered:
            return item
    if path.startswith("shared/src/domain/") and len(parts) > 3:
        return parts[3]
    if path.startswith("shared/src/api/") and len(parts) > 3:
        return parts[3]
    return "cross_cutting"


def kind_for(path: str, text: str) -> str:
    if path.endswith("_test.gleam") or "/test/" in path:
        return "test"
    if path.endswith(".sql"):
        return "sql"
    if path.endswith(".mjs"):
        return "ffi" if ".ffi." in path or "ffi" in path else "script"
    if path.endswith((".toml", ".yml", ".yaml")):
        return "config"
    if path.endswith(".md"):
        return "docs"
    if path.endswith(".sh"):
        return "script"
    if not path.endswith(".gleam"):
        return "support"
    if "/web/router.gleam" in path:
        return "route"
    if "/http/" in path:
        return "endpoint_handler"
    if "/api/" in path and path.startswith("apps/client/src/"):
        return "api_client"
    if "/use_case/" in path:
        return "use_case"
    if "/repository/" in path:
        return "repository"
    if "/domain/" in path or "/shared/src/domain/" in path:
        return "domain_model"
    if "/shared/src/api/" in path:
        return "contract"
    if "/components/" in path or "/ui/" in path:
        if "lustre.component" in text:
            return "lustre_component"
        return "lustre_view"
    if "/features/" in path:
        name = Path(path).name
        if name.endswith("_route.gleam") or "/route" in path:
            return "lustre_route"
        if "update" in name:
            return "lustre_update"
        if "view" in name or "html." in text or "Element(" in text:
            return "lustre_view"
        return "module"
    if "lustre.component" in text:
        return "lustre_component"
    if "pub fn view" in text or "html." in text:
        return "lustre_view"
    return "module"


IMPORT_RE = re.compile(r"^import\s+([A-Za-z0-9_./]+)", re.MULTILINE)
PUB_RE = re.compile(r"^pub\s+(opaque\s+type|type|fn|const)\s+([A-Za-z0-9_]+)", re.MULTILINE)
FN_RE = re.compile(r"^(?:pub\s+)?fn\s+([A-Za-z0-9_]+)", re.MULTILINE)
TEST_RE = re.compile(r"^pub\s+fn\s+([A-Za-z0-9_]+_test)\s*\(", re.MULTILINE)


def public_symbols(text: str) -> list[str]:
    return [f"{kind} {name}" for kind, name in PUB_RE.findall(text)]


def imports(text: str) -> list[str]:
    return sorted(set(IMPORT_RE.findall(text)))


def functions(text: str) -> list[str]:
    return sorted(set(FN_RE.findall(text)))


def tests_declared(text: str) -> list[str]:
    return sorted(set(TEST_RE.findall(text)))


def module_path_to_file(mod: str, files: set[str]) -> str | None:
    candidates = [
        f"apps/client/src/{mod}.gleam",
        f"apps/server/src/{mod}.gleam",
        f"shared/src/{mod}.gleam",
        f"apps/client/test/{mod.removeprefix('test/')}.gleam",
        f"apps/server/test/{mod.removeprefix('test/')}.gleam",
        f"shared/test/{mod.removeprefix('test/')}.gleam",
    ]
    for candidate in candidates:
        if candidate in files:
            return candidate
    return None


def route_patterns(router_text: str) -> list[dict[str, object]]:
    lines = router_text.splitlines()
    endpoints: list[dict[str, object]] = []
    index = 0
    while index < len(lines):
        line = lines[index]
        if "[" not in line:
            index += 1
            continue
        start = index
        block = line
        while "]" not in block and index + 1 < len(lines):
            index += 1
            block += "\n" + lines[index]
        if '"api"' not in block:
            index += 1
            continue
        if "]" not in block:
            index += 1
            continue
        segment_block = block.split("]", 1)[0] + "]"
        segment_tokens = [
            token.strip().strip(",")
            for token in segment_block.strip("[] \n").split(",")
            if token.strip().strip(",")
        ]
        segments: list[str] = []
        for token in segment_tokens:
            token = token.strip()
            if token.startswith('"') and token.endswith('"'):
                segments.append(token.strip('"'))
            else:
                segments.append("{" + token + "}")
        lookahead = "\n".join(lines[start : min(len(lines), start + 14)])
        handler = ""
        match = re.search(r"Some\(\s*([A-Za-z0-9_]+)\.([A-Za-z0-9_]+)\(", lookahead)
        if match:
            handler = f"{match.group(1)}.{match.group(2)}"
        path = "/" + "/".join(segments)
        endpoints.append(
            {
                "path": path,
                "router_line": start + 1,
                "handler": handler,
                "domain": endpoint_domain(path),
            }
        )
        index += 1
    unique = {}
    for endpoint in endpoints:
        key = (endpoint["path"], endpoint["handler"])
        unique[key] = endpoint
    return list(unique.values())


def endpoint_domain(path: str) -> str:
    segments = [segment for segment in path.split("/") if segment]
    for preferred in [
        "auth",
        "org",
        "projects",
        "cards",
        "tasks",
        "capabilities",
        "workflows",
        "rules",
        "task-templates",
        "task-types",
        "views",
        "me",
        "api-tokens",
        "integration-users",
    ]:
        if preferred in segments:
            return preferred.replace("-", "_")
    return segments[2] if len(segments) > 2 else "cross_cutting"


def normalize_client_endpoint(expr: str) -> str:
    tokens: list[tuple[int, str, bool]] = []
    for match in re.finditer(r'"([^"]*)"|int\.to_string\(([A-Za-z0-9_]+)\)|encode_uri_component\(([A-Za-z0-9_]+)\)', expr):
        value = match.group(1)
        int_var = match.group(2)
        enc_var = match.group(3)
        if value is not None:
            tokens.append((match.start(), value, True))
        elif int_var is not None:
            tokens.append((match.start(), "{" + int_var + "}", False))
        elif enc_var is not None:
            tokens.append((match.start(), "{" + enc_var + "}", False))
    output = ""
    started = False
    for _, token, is_string in tokens:
        if "/api/v1" in token and started:
            break
        if "/api/v1" in token:
            started = True
        if started:
            if is_string and output and not (
                token.startswith("/")
                or token.startswith("?")
                or token.startswith("&")
                or token == ""
            ):
                break
            output += token
    if not output.startswith("/api/v1"):
        return ""
    output = output.split("?", 1)[0].split("&", 1)[0]
    output = output.replace("//", "/")
    return output.rstrip("/") or output


def client_endpoints(files: list[str]) -> list[dict[str, object]]:
    endpoints = []
    for path in files:
        if not path.endswith(".gleam") or not path.startswith("apps/client/src/"):
            continue
        text = read_text(path)
        if "/api/v1" not in text:
            continue
        lines = text.splitlines()
        for i, line in enumerate(lines):
            if "/api/v1" not in line:
                continue
            if line.lstrip().startswith(("//", "///", "////")):
                continue
            expr = "\n".join(lines[i : min(len(lines), i + 8)])
            normalized = normalize_client_endpoint(expr)
            if not normalized:
                literal = re.search(r'("(/api/v1[^"]*)")', line)
                normalized = literal.group(2) if literal else ""
            if normalized:
                endpoints.append(
                    {
                        "path": normalized,
                        "file": path,
                        "line": i + 1,
                        "domain": endpoint_domain(normalized),
                    }
                )
    unique = {}
    for endpoint in endpoints:
        unique[(endpoint["path"], endpoint["file"], endpoint["line"])] = endpoint
    return list(unique.values())


def endpoint_shape(path: str) -> str:
    path = path.split("?", 1)[0].rstrip("/")
    parts = []
    for segment in path.split("/"):
        if not segment:
            continue
        if segment.startswith("{") and segment.endswith("}"):
            parts.append("{}")
        else:
            parts.append(segment)
    return "/" + "/".join(parts)


def method_hints(handler: str) -> list[str]:
    if not handler:
        return []
    module, _, fn_name = handler.partition(".")
    path = ROOT / "apps" / "server" / "src" / "scrumbringer_server" / "http" / f"{module}.gleam"
    if not path.exists():
        return []
    text = path.read_text(encoding="utf-8")
    idx = text.find(f"pub fn {fn_name}")
    if idx == -1:
        idx = text.find(f"fn {fn_name}")
    body = text[idx : idx + 1800] if idx != -1 else text
    hints = []
    for method in ["Get", "Post", "Patch", "Put", "Delete"]:
        if re.search(rf"\b{method}\b", body):
            hints.append(method.upper())
    return hints


def yaml_scalar(value: object) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    text = str(value)
    if text == "":
        return "''"
    if re.match(r"^[A-Za-z0-9_./{}:+?=& -]+$", text) and not text.startswith(("-", "{", "[")):
        return text
    return repr(text)


def write_yaml(path: Path, items: list[dict[str, object]]) -> None:
    lines = [
        "# Generated by scripts/codebase_audit.py. Review manually before acting.",
        f"# Generated at {dt.datetime.now(dt.timezone.utc).isoformat()}",
    ]
    for item in items:
        lines.append("- path: " + yaml_scalar(item.get("path", "")))
        for key, value in item.items():
            if key == "path":
                continue
            if isinstance(value, list):
                lines.append(f"  {key}:")
                if value:
                    for entry in value:
                        lines.append("    - " + yaml_scalar(entry))
                else:
                    lines.append("    []")
            else:
                lines.append(f"  {key}: {yaml_scalar(value)}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def md_table(headers: list[str], rows: list[list[object]]) -> str:
    output = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join(["---"] * len(headers)) + " |",
    ]
    for row in rows:
        output.append("| " + " | ".join(str(cell).replace("\n", " ") for cell in row) + " |")
    return "\n".join(output)


def build_inventory(files: list[str]) -> tuple[list[dict[str, object]], dict[str, dict[str, object]]]:
    file_set = set(files)
    module_to_path = {
        module_name(path): path for path in files if path.endswith(".gleam")
    }
    raw: dict[str, dict[str, object]] = {}
    for path in files:
        text = read_text(path)
        item = {
            "path": path,
            "package": package_for(path),
            "layer": layer_for(path),
            "kind": kind_for(path, text),
            "domain": domain_for(path),
            "module": module_name(path) if path.endswith(".gleam") else "",
            "lines": text.count("\n") + 1 if text else 0,
            "public_symbols": public_symbols(text) if path.endswith(".gleam") else [],
            "imports": imports(text) if path.endswith(".gleam") else [],
            "imported_by": [],
            "functions": functions(text) if path.endswith(".gleam") else [],
            "tests_declared": tests_declared(text) if path.endswith(".gleam") else [],
            "uses_dynamic": bool(re.search(r"\bDynamic\b|gleam/dynamic|decode\.dynamic", text)),
            "uses_ffi": "@external" in text or path.endswith(".mjs"),
            "uses_json": "gleam/json" in text or "json." in text,
            "uses_sql": path.endswith(".sql") or "/sql/" in path or "scrumbringer_server/sql" in text,
            "side_effects": side_effects(path, text),
        }
        raw[path] = item

    imported_by: dict[str, list[str]] = collections.defaultdict(list)
    for path, item in raw.items():
        for mod in item["imports"]:  # type: ignore[index]
            target = module_to_path.get(mod) or module_path_to_file(mod, file_set)
            if target:
                imported_by[target].append(path)
    for path, consumers in imported_by.items():
        raw[path]["imported_by"] = sorted(set(consumers))

    return [raw[path] for path in sorted(raw)], raw


def side_effects(path: str, text: str) -> list[str]:
    effects = []
    if "core.request" in text or "request_nil" in text:
        effects.append("http_client")
    if "wisp." in text or "Request" in text and "Response" in text:
        effects.append("http_server")
    if "pog." in text or "/sql/" in path or path.endswith(".sql"):
        effects.append("database")
    if "@external" in text or path.endswith(".mjs"):
        effects.append("ffi")
    if "effect." in text:
        effects.append("lustre_effect")
    if "localStorage" in text or "cookie" in path.lower():
        effects.append("browser_storage")
    return effects


def component_records(inventory: list[dict[str, object]]) -> list[dict[str, object]]:
    records = []
    for item in inventory:
        if item["package"] != "client" or not str(item["path"]).endswith(".gleam"):
            continue
        if item["layer"] == "test" or item["kind"] == "test":
            continue
        kind = str(item["kind"])
        text = read_text(str(item["path"]))
        if kind not in {"lustre_component", "lustre_view", "lustre_route", "lustre_update"}:
            if "Element(" not in text and "html." not in text and "view" not in str(item["path"]):
                continue
        records.append(
            {
                "component": module_name(str(item["path"])),
                "path": item["path"],
                "kind": kind,
                "domain": item["domain"],
                "public_api": len(item["public_symbols"]),  # type: ignore[arg-type]
                "parents": len(item["imported_by"]),  # type: ignore[arg-type]
                "state_owned": "pub type Model" in text or "\ntype Model" in text,
                "messages": "pub type Msg" in text or "\ntype Msg" in text,
                "effects": "effect." in text,
                "css_classes": text.count("class("),
                "icons": "icons." in text or "/icons" in text,
                "tooltips": "tooltip" in text.lower() or "title(" in text,
                "aria": "aria_" in text or "attribute.role" in text,
                "keyboard_support": "keydown" in text.lower() or "Key" in text,
                "dynamic_lists_keyed": "keyed.element" in text,
                "tests": [],
            }
        )
    return records


def test_records(inventory: list[dict[str, object]]) -> list[dict[str, object]]:
    records = []
    for item in inventory:
        if item["kind"] != "test":
            continue
        path = str(item["path"])
        text = read_text(path)
        test_type = []
        if "simulate.request" in text or "/api/v1" in text:
            test_type.append("endpoint")
        if "element.to_document_string" in text or "view(" in text:
            test_type.append("lustre_view")
        if "try_update" in text or "update(" in text:
            test_type.append("lustre_update")
        if "decoder" in text or "to_json" in text or "from_json" in text:
            test_type.append("contract")
        if not test_type:
            test_type.append("unit")
        records.append(
            {
                "test_file": path,
                "package": item["package"],
                "test_type": ", ".join(test_type),
                "tests_declared": len(item["tests_declared"]),  # type: ignore[arg-type]
                "subjects_under_test": ", ".join(item["imports"][:8]),  # type: ignore[index]
                "uses_let_assert": "let assert" in text,
                "uses_deprecated_should": "gleeunit/should" in text or "/should" in text,
                "uses_private_helpers_signal": bool(re.search(r"\.(handle_|success_effect|apply_)", text)),
                "snapshot_status": "birdie" if "birdie" in text else "none",
            }
        )
    return records


def write_endpoint_map(server_eps: list[dict[str, object]], client_eps: list[dict[str, object]], inventory: list[dict[str, object]]) -> None:
    tests = [item for item in inventory if item["kind"] == "test"]
    client_by_shape = collections.defaultdict(list)
    for endpoint in client_eps:
        client_by_shape[endpoint_shape(str(endpoint["path"]))].append(endpoint)
    server_shapes = {endpoint_shape(str(endpoint["path"])) for endpoint in server_eps}

    lines = [
        "# Endpoint map",
        "",
        "Generated by `scripts/codebase_audit.py`. Method hints are inferred from handler bodies and must be reviewed manually.",
        "",
        f"- Server route patterns: {len(server_eps)}",
        f"- Client API call sites: {len(client_eps)}",
        f"- Client endpoint shapes not found in router: {len([e for e in client_eps if endpoint_shape(str(e['path'])) not in server_shapes])}",
        "",
    ]
    rows = []
    for endpoint in sorted(server_eps, key=lambda e: str(e["path"])):
        shape = endpoint_shape(str(endpoint["path"]))
        callers = client_by_shape.get(shape, [])
        test_hits = [
            str(test["path"])
            for test in tests
            if str(endpoint["path"]).replace("{", "").split("}")[0].strip("/") in read_text(str(test["path"]))
        ][:5]
        rows.append(
            [
                ", ".join(method_hints(str(endpoint["handler"]))) or "review",
                endpoint["path"],
                endpoint["handler"] or "review",
                endpoint["domain"],
                len(callers),
                len(test_hits),
            ]
        )
    lines.append(md_table(["Method", "Path", "Handler", "Domain", "Client callers", "Test hits"], rows))
    lines.append("")
    missing_rows = []
    for endpoint in sorted(client_eps, key=lambda e: (str(e["path"]), str(e["file"]))):
        if endpoint_shape(str(endpoint["path"])) not in server_shapes:
            missing_rows.append([endpoint["path"], endpoint["file"], endpoint["line"]])
    lines.append("## Client API call shapes without exact router shape")
    lines.append("")
    if missing_rows:
        lines.append(md_table(["Client path", "File", "Line"], missing_rows))
    else:
        lines.append("No exact-shape mismatches detected by the static extractor.")
    lines.append("")
    (OUT / "endpoint-map.md").write_text("\n".join(lines), encoding="utf-8")


def write_component_map(components: list[dict[str, object]], tests: list[dict[str, object]]) -> None:
    rows = []
    for component in sorted(components, key=lambda c: str(c["path"])):
        matching_tests = [
            test["test_file"]
            for test in tests
            if Path(str(component["path"])).stem in str(test["test_file"])
            or str(component["domain"]) in str(test["test_file"])
        ][:4]
        rows.append(
            [
                component["component"],
                component["kind"],
                component["domain"],
                component["parents"],
                "yes" if component["state_owned"] else "no",
                "yes" if component["aria"] else "no",
                "yes" if component["keyboard_support"] else "no",
                len(matching_tests),
            ]
        )
    text = [
        "# Component map",
        "",
        "Frontend component/view inventory derived from Lustre modules.",
        "",
        md_table(
            ["Component", "Kind", "Domain", "Parents", "State", "ARIA", "Keyboard", "Test hits"],
            rows,
        ),
        "",
    ]
    (OUT / "component-map.md").write_text("\n".join(text), encoding="utf-8")


def write_module_map(inventory: list[dict[str, object]]) -> None:
    rows = []
    for item in inventory:
        if not str(item["path"]).endswith(".gleam"):
            continue
        rows.append(
            [
                item["module"],
                item["package"],
                item["kind"],
                item["domain"],
                item["lines"],
                len(item["public_symbols"]),  # type: ignore[arg-type]
                len(item["imports"]),  # type: ignore[arg-type]
                len(item["imported_by"]),  # type: ignore[arg-type]
            ]
        )
    text = [
        "# Module map",
        "",
        "All Gleam modules in scope. High public surface with few consumers is a candidate for manual review.",
        "",
        md_table(["Module", "Package", "Kind", "Domain", "Lines", "Public", "Imports", "Consumers"], rows),
        "",
    ]
    (OUT / "module-map.md").write_text("\n".join(text), encoding="utf-8")


def write_test_map(tests: list[dict[str, object]]) -> None:
    rows = [
        [
            test["test_file"],
            test["package"],
            test["test_type"],
            test["tests_declared"],
            "yes" if test["uses_let_assert"] else "no",
            "yes" if test["uses_deprecated_should"] else "no",
            "yes" if test["uses_private_helpers_signal"] else "no",
        ]
        for test in sorted(tests, key=lambda t: str(t["test_file"]))
    ]
    text = [
        "# Test coverage map",
        "",
        "Static map of test files and their likely subjects. Private-helper signals require manual review.",
        "",
        md_table(["Test file", "Package", "Type", "Tests", "let assert", "should", "Private-helper signal"], rows),
        "",
    ]
    (OUT / "test-coverage-map.md").write_text("\n".join(text), encoding="utf-8")


def duplicate_basenames(inventory: list[dict[str, object]]) -> list[tuple[str, list[dict[str, object]]]]:
    groups: dict[str, list[dict[str, object]]] = collections.defaultdict(list)
    for item in inventory:
        if str(item["path"]).endswith(".gleam"):
            groups[Path(str(item["path"])).stem].append(item)
    return sorted(
        [(name, items) for name, items in groups.items() if len({i["package"] for i in items}) > 1],
        key=lambda pair: (-len(pair[1]), pair[0]),
    )


def client_endpoints_without_server_shape(
    server_eps: list[dict[str, object]],
    client_eps: list[dict[str, object]],
) -> list[dict[str, object]]:
    server_shapes = {endpoint_shape(str(endpoint["path"])) for endpoint in server_eps}
    return [
        endpoint for endpoint in client_eps if endpoint_shape(str(endpoint["path"])) not in server_shapes
    ]


def write_refactor_candidates(
    inventory: list[dict[str, object]],
    server_eps: list[dict[str, object]],
    client_eps: list[dict[str, object]],
    components: list[dict[str, object]],
    tests: list[dict[str, object]],
) -> None:
    client_missing = client_endpoints_without_server_shape(server_eps, client_eps)
    large_modules = [
        item for item in inventory if str(item["path"]).endswith(".gleam") and int(item["lines"]) >= 700
    ]
    no_consumer_public = [
        item
        for item in inventory
        if str(item["path"]).endswith(".gleam")
        and item["public_symbols"]
        and not item["imported_by"]
        and item["kind"] not in {"route", "test"}
    ]
    deprecated_should = [test for test in tests if test["uses_deprecated_should"]]
    private_helper_tests = [test for test in tests if test["uses_private_helpers_signal"]]
    duplicate_names = duplicate_basenames(inventory)[:25]

    lines = [
        "# Refactor candidates",
        "",
        "These candidates are generated from the inventory and then curated with manual architectural judgement. They are not implementation instructions until converted into work packages.",
        "",
        "## P0/P1 mechanically detected signals",
        "",
        f"- Client API shapes without exact router shape: {len(client_missing)}",
        f"- Gleam modules >= 700 lines: {len(large_modules)}",
        f"- Public modules with no static consumers: {len(no_consumer_public)}",
        f"- Tests importing deprecated should: {len(deprecated_should)}",
        f"- Tests with private-helper coupling signals: {len(private_helper_tests)}",
        f"- Basenames duplicated across packages: {len(duplicate_basenames(inventory))}",
        "",
        "## Curated candidates",
        "",
    ]

    curated = []
    if client_missing:
        curated.append({
            "id": "AUD-WP-00",
            "priority": "P0",
            "title": "Resolver API cliente sin ruta backend",
            "evidence": "Hay endpoints cliente sin shape exacta en el router.",
            "target_owner": "Eliminar la funcion cliente si es dead code, o implementar/trazar explicitamente la ruta si el producto la necesita.",
            "delete": "Funcion cliente, comentario stale del handler correspondiente y test/fixture asociado si se confirma que no hay flujo vivo.",
        })
    else:
        lines.extend([
            "Resolved: no client API shape currently lacks an exact router shape, so the previous card-tasks mismatch is no longer an actionable P0.",
            "",
        ])

    resource_views_candidate = {
        "id": "AUD-WP-02",
        "priority": "P2" if resource_views_shared() else "P1",
        "title": "Endurecer resource views de tasks/cards" if resource_views_shared() else "Unificar resource views de tasks/cards",
        "evidence": "Task/card views ya delegan en `http/resource_views.gleam`; el trabajo restante es cobertura y evitar una segunda abstraccion." if resource_views_shared() else "Rutas `/api/v1/views/tasks/{id}` y `/api/v1/views/cards/{id}` tienen shape de comportamiento equivalente.",
        "target_owner": "`http/resource_views.gleam` como flujo HTTP comun; `task_views` y `card_views` conservan autorizacion/carga de proyecto especifica." if resource_views_shared() else "Presenter/use case comun para registrar vista de recurso con ADT ResourceViewed(Task|Card).",
        "delete": "No introducir ADT ni helpers nuevos si `resource_views` ya cubre el caso; retirar solo duplicacion residual de tests o mapeos." if resource_views_shared() else "Duplicacion de handler/presenter/test de views conservando autorizacion especifica.",
    }

    curated.extend([
        {
            "id": "AUD-WP-01",
            "priority": "P1",
            "title": "Unificar superficies Task/Card notes",
            "evidence": "Existen endpoints, API client, UI lists y tests paralelos para task notes y card notes.",
            "target_owner": "Un contrato compartido de note + presenters/decoders comunes, manteniendo handlers por recurso si la autorizacion difiere.",
            "delete": "Helpers, fixtures y render fragments duplicados tras extraer note_content/notes_list y contrato comun.",
        },
        resource_views_candidate,
        {
            "id": "AUD-WP-03",
            "priority": "P1",
            "title": "Cerrar ownership de Card Show y Task Show",
            "evidence": "Componentes show, inspector shell/actions/header y tests viven repartidos entre features y ui.",
            "target_owner": "Features `cards/show` y `tasks/show` para estado/producto; `ui/inspector_*` solo primitivas visuales testeadas.",
            "delete": "Configuracion local, acciones sueltas y tests que fuerzan public API de componentes internos.",
        },
        {
            "id": "AUD-WP-04",
            "priority": "P2",
            "title": "Consolidar metricas visuales de task/card",
            "evidence": "Componentes `task_metric`, `card_progress`, badges y summaries comparten lenguaje visual de contadores/estados.",
            "target_owner": "Primitivas UI semanticas para metricas con icono, tooltip, label accesible y tests comunes.",
            "delete": "Markup local de badges/texto y tests duplicados por feature.",
        },
        {
            "id": "AUD-WP-05",
            "priority": "P2",
            "title": "Privatizar API publica accidental usada solo por tests",
            "evidence": "Tests con senales de acoplamiento a helpers `handle_`, `apply_` o success effects.",
            "target_owner": "Entradas publicas de produccion: route/update/handler HTTP; helpers puros privados salvo consumidores reales.",
            "delete": "Exports publicos accidentales y tests de implementacion.",
        },
        {
            "id": "AUD-WP-06",
            "priority": "P2",
            "title": "Revisar modulos grandes por responsabilidad real",
            "evidence": "Modulos >= 700 lineas detectados por inventario.",
            "target_owner": "Cortes locales por responsabilidad de producto, no por patron generico.",
            "delete": "Ramas repetidas y helpers privados movidos solo si el nuevo owner elimina conocimiento del root.",
        },
    ])
    rows = [[c["id"], c["priority"], c["title"], c["target_owner"], c["delete"]] for c in curated]
    lines.append(md_table(["ID", "Priority", "Title", "Target owner", "Code/API to remove"], rows))
    lines.append("")

    lines.append("## Client API shapes needing manual verification")
    lines.append("")
    if client_missing:
        rows = [[e["path"], e["file"], e["line"]] for e in client_missing[:80]]
        lines.append(md_table(["Client path", "File", "Line"], rows))
    else:
        lines.append("No exact-shape mismatches detected.")
    lines.append("")

    lines.append("## Large modules")
    lines.append("")
    if large_modules:
        rows = [[m["path"], m["lines"], m["kind"], m["domain"], len(m["public_symbols"])] for m in large_modules]
        lines.append(md_table(["Path", "Lines", "Kind", "Domain", "Public symbols"], rows))
    else:
        lines.append("No modules >= 700 lines.")
    lines.append("")

    lines.append("## Duplicate module basenames across packages")
    lines.append("")
    rows = [[name, ", ".join(str(item["path"]) for item in items[:6])] for name, items in duplicate_names]
    lines.append(md_table(["Basename", "Files"], rows) if rows else "No duplicate basenames across packages.")
    lines.append("")

    (OUT / "refactor-candidates.md").write_text("\n".join(lines), encoding="utf-8")


def write_work_packages(
    has_client_endpoint_mismatches: bool,
    has_shared_resource_views: bool,
) -> None:
    resolved_wp00 = "" if has_client_endpoint_mismatches else """## Completed packages

- WP-00: the previous client-only card tasks endpoint was resolved by deleting the dead client API and stale backend route comment. `endpoint-map.md` now reports zero client endpoint shapes without router shape.

"""
    wp00 = """## WP-00: Resolve dead or missing Card tasks endpoint

### Problem

The client API exposes a route shape that the server router does not expose, so the codebase carries an implicit client-only contract.

### Evidence

See `endpoint-map.md` section "Client API shapes without exact router shape".

### Design decision

Prefer deletion if no production consumer exists. If the product needs the endpoint, implement it through the router and tests instead of leaving an implicit client-only contract.

### Code to remove

- Dead client API function and usage docs if unused.
- Stale handler comments and test fixtures that preserve the dead contract.

### Acceptance criteria

- `endpoint-map.md` has no client-only shape for the endpoint.
- `rg` for the removed client helper and raw path returns only justified live references.
- If implemented rather than deleted, server endpoint tests cover method, auth and not-found behavior.

""" if has_client_endpoint_mismatches else ""

    wp02 = """## WP-02: Resource view tracking coverage hardening

### Current state

Task/card view registration already shares the HTTP flow through `http/resource_views.gleam`; `task_views.gleam` and `card_views.gleam` only keep resource-specific project lookup and error mapping.

### Problem

The remaining risk is not duplicated production flow, but weak regression coverage around the shared flow and accidental reintroduction of local status mapping.

### Evidence

- `/api/v1/views/tasks/{task_id}`
- `/api/v1/views/cards/{card_id}`
- `http/resource_views.gleam`
- `http/task_views.gleam`
- `http/card_views.gleam`

### Design decision

Keep the current small shared handler. Do not introduce a `ResourceViewed(Task|Card)` ADT unless a future use case needs resource values outside HTTP routing.

### Code to remove

- Any future duplicate response/status mapping inside `task_views.gleam` or `card_views.gleam`.
- Tests that duplicate the same shared status matrix without resource-specific authorization value.

### Acceptance criteria

- Tests cover task and card authorization separately.
- Shared flow remains in `http/resource_views.gleam`.
- `task_views.gleam` and `card_views.gleam` stay limited to project lookup and resource-specific error mapping.

""" if has_shared_resource_views else """## WP-02: Resource view tracking unification

### Problem

Task/card view registration exposes equivalent resource-view behavior through parallel modules.

### Evidence

- `/api/v1/views/tasks/{task_id}`
- `/api/v1/views/cards/{card_id}`
- `http/task_views.gleam`
- `http/card_views.gleam`

### Design decision

Introduce a small domain ADT for viewed resource only if it lets the server share presenter/use-case logic without weakening authorization.

### Code to remove

- Duplicate response/status mapping.
- Duplicate tests for identical success/error mapping.

### Acceptance criteria

- Tests cover task and card authorization separately.
- Shared logic is pure and independently tested.

"""

    text = f"""# Refactor work packages

These packages are derived from `refactor-candidates.md`. They are intentionally small enough to execute independently after the audit is reviewed.

{resolved_wp00}{wp00}## WP-01: Notes contract and presentation unification

### Problem

Task notes and card notes repeat endpoint shapes, client API calls, UI note rendering and test fixtures.

### Evidence

- Server: `http/task_notes.gleam`, `http/card_notes.gleam`, note SQL files.
- Client: `api/tasks/notes.gleam`, card note calls in `api/cards.gleam`.
- UI: note rendering in task show, card show and shared note UI modules.

### Design decision

Keep resource-specific handlers if authorization differs, but extract shared note contract/presenter/rendering and shared test fixtures.

### Changes planned

- Add or reuse a shared `NoteResource`/`ResourceNote` ADT if it removes duplicated branch logic.
- Keep Parse -> Process -> Present in handlers.
- Move common note HTML into `ui/notes_list`/`ui/note_content`.
- Rewrite tests around public endpoints and rendered output.

### Code to remove

- Duplicate note JSON mappers.
- Repeated note list markup in show views.
- Duplicated fixtures that only differ by task/card prefix.

### Acceptance criteria

- Both task and card notes still pass endpoint tests.
- Shared note rendering has focused tests.
- No generic CRUD abstraction is introduced.

{wp02}## WP-03: Inspector/show ownership hardening

### Problem

Card Show and Task Show share inspector primitives but product state still risks leaking into `ui/`.

### Evidence

- `features/cards/show*`
- `features/tasks/show/*`
- `ui/inspector_*`
- inspector tests.

### Design decision

`ui/inspector_*` owns visual shell/actions only. Product-specific sections, state, messages and effects stay in `features/cards/show` or `features/tasks/show`.

### Code to remove

- Product conditionals from UI primitives.
- Duplicate local action-menu markup.
- Tests that import internals instead of rendering the public show surface.

### Acceptance criteria

- UI primitives have snapshot/string render tests with accessible labels.
- Show features cover public behavior via route/update/view entry points.

## WP-04: Status metric visual language consolidation

### Problem

Totals, closed, blocked, available, claimed and in-progress metrics are represented with mixed text/icon/badge patterns.

### Evidence

- `ui/task_metric.gleam`
- `ui/card_progress.gleam`
- feature-local badges in pool/card/task views.

### Design decision

Create semantic metric primitives with icon, numeric value, tooltip and accessible label. Keep domain-specific aggregation outside the primitive.

### Code to remove

- Local text badges for the same metric concepts.
- Repeated icon+number markup.

### Acceptance criteria

- Hover/title or equivalent accessible label exists for every icon-only metric.
- Tests cover labels and numeric output.

## WP-05: Public API accidental surface cleanup

### Problem

Some tests appear to couple to internal helpers, forcing public APIs that production does not need.

### Evidence

See `test-coverage-map.md` rows marked with `Private-helper signal`.

### Design decision

Tests should enter through production entry points unless the helper is a pure, intentionally shared module.

### Code to remove

- `pub fn` handlers used only by tests.
- Test-only success wrappers in production modules.

### Acceptance criteria

- `rg "\\.(handle_|success_effect|apply_)" apps/client/test apps/server/test` is reviewed and reduced to justified cases.
- Privatized helpers remain covered through public behavior.

## WP-06: Large module responsibility review

### Problem

Large modules can hide multiple responsibilities, but splitting by line count alone creates churn.

### Evidence

See `refactor-candidates.md` large modules table.

### Design decision

Split only when a new local owner removes duplicated branches, effect orchestration or unrelated view sections.

### Code to remove

- Repeated branches in route/update roots.
- Private helpers that become local to the new owner.

### Acceptance criteria

- Each split leaves fewer responsibilities in the original module.
- New modules have focused tests or are covered by public route/update/view tests.
"""
    (OUT / "refactor-work-packages.md").write_text(text, encoding="utf-8")


def write_summary(
    inventory: list[dict[str, object]],
    server_eps: list[dict[str, object]],
    client_eps: list[dict[str, object]],
    components: list[dict[str, object]],
    tests: list[dict[str, object]],
) -> None:
    by_package = collections.Counter(str(item["package"]) for item in inventory)
    by_kind = collections.Counter(str(item["kind"]) for item in inventory)
    client_missing = client_endpoints_without_server_shape(server_eps, client_eps)
    client_endpoint_finding = (
        f"1. P0: {len(client_missing)} client API shape(s) do not have an exact router shape. Resolve each by deleting dead client API or implementing a traced backend route with tests."
        if client_missing
        else "1. Resolved: no client API shape currently lacks an exact router shape. The previous card-tasks client-only endpoint is no longer an open P0."
    )
    priority_rows = []
    if client_missing:
        priority_rows.append([
            "P0",
            "Client-only endpoint shapes",
            "Potential dead API surface or missing backend route.",
        ])
    priority_rows.extend([
        ["P1", "Task/Card notes", "Repeated endpoint/client/UI/test surface with high reuse potential."],
        ["P1", "Task/Card resource views", "Same behavioral shape with separate handlers and tests."],
        ["P1", "Card/Task show inspector ownership", "Product state and UI primitives are adjacent and should keep clean boundaries."],
        ["P2", "Metric visual language", "Repeated counters/badges should share accessible semantic primitives."],
        ["P2", "Public API accidental surface", "Tests may keep internals public."],
    ])
    lines = [
        "# Codebase file-by-file audit",
        "",
        f"Generated: {dt.date.today().isoformat()}",
        "",
        "## Scope and baseline",
        "",
        f"- HEAD at generation time: `{run(['git', 'rev-parse', 'HEAD']).strip()}`",
        f"- Files inventoried: {len(inventory)}",
        f"- Gleam modules inventoried: {sum(1 for item in inventory if str(item['path']).endswith('.gleam'))}",
        f"- Server route patterns inventoried: {len(server_eps)}",
        f"- Client API call sites inventoried: {len(client_eps)}",
        f"- Frontend component/view/update candidates inventoried: {len(components)}",
        f"- Test files inventoried: {len(tests)}",
        "",
        "The inventory includes tracked files plus untracked, non-ignored files in the current worktree, because the worktree is the authoritative state for this audit.",
        "",
        "## Inventory by package",
        "",
        md_table(["Package", "Files"], [[key, value] for key, value in sorted(by_package.items())]),
        "",
        "## Inventory by kind",
        "",
        md_table(["Kind", "Files"], [[key, value] for key, value in sorted(by_kind.items())]),
        "",
        "## Main findings",
        "",
        client_endpoint_finding,
        "2. P1: the codebase has parallel resource families where unification should be driven by domain adjacency, not by file size. The strongest families are task/card notes, task/card view tracking, task/card show inspector surfaces and status metrics.",
        "3. P1: backend route coverage is centralized and discoverable in `web/router.gleam`, but method/status matrices live in handlers and tests; endpoint refactors must preserve Parse -> Process -> Present boundaries.",
        "4. P2: frontend has many feature-local views and update modules. This is healthy when it preserves product ownership, but repeated UI language should be pulled into semantic UI primitives with accessible labels and tests.",
        "5. P2: shared modules should remain reserved for full-stack contracts and canonical domain types. The duplicate-basename report is a prompt for review, not permission to move everything to shared.",
        "6. P2: tests mostly use public behavior, but rows marked with private-helper signals should be audited because they can keep accidental `pub fn` surfaces alive.",
        "",
        "## Responsibility audit",
        "",
        "- Backend: handlers should keep HTTP Parse -> Process -> Present, while repositories/SQL remain storage owners. Candidate unifications should target presenters/contracts first, not merge route families blindly.",
        "- Frontend: `features/*` should own product state, messages and effects. `ui/*` should own visual primitives, accessibility and reusable rendering only.",
        "- Shared: only canonical domain types and full-stack contracts should move here. Same basename across packages is evidence for review, not automatic shared extraction.",
        "- Tests: tests should protect public behavior. Any test preserving a public helper that production does not need should be rewritten before privatizing that helper.",
        "",
        "## Priority order",
        "",
        md_table(
            ["Priority", "Area", "Reason"],
            priority_rows,
        ),
        "",
        "## Deliverables",
        "",
        "- `codebase-inventory.yml`: file-by-file inventory.",
        "- `endpoint-map.md`: server routes, handlers, client call-site counts and static mismatches.",
        "- `component-map.md`: frontend views/components with state/accessibility/test signals.",
        "- `module-map.md`: all Gleam modules with public surface and consumers.",
        "- `test-coverage-map.md`: tests by type and coupling signal.",
        "- `refactor-candidates.md`: prioritized candidates and detected risk signals.",
        "- `refactor-work-packages.md`: executable packages for the next phase.",
        "",
        "## Completion status",
        "",
        "This audit has completed the inventory and generated the requested maps. The next step is not to refactor globally, but to review and execute the work packages one by one, starting with candidates that delete duplicated code or close accidental public APIs.",
        "",
    ]
    (OUT / "codebase-file-by-file-audit.md").write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    files = [path for path in tracked_and_untracked_files() if in_scope(path)]
    inventory, _raw = build_inventory(files)
    write_yaml(OUT / "codebase-inventory.yml", inventory)

    router_path = ROOT / "apps/server/src/scrumbringer_server/web/router.gleam"
    server_eps = route_patterns(router_path.read_text(encoding="utf-8")) if router_path.exists() else []
    client_eps = client_endpoints(files)
    components = component_records(inventory)
    tests = test_records(inventory)

    write_endpoint_map(server_eps, client_eps, inventory)
    write_component_map(components, tests)
    write_module_map(inventory)
    write_test_map(tests)
    write_refactor_candidates(inventory, server_eps, client_eps, components, tests)
    write_work_packages(
        bool(client_endpoints_without_server_shape(server_eps, client_eps)),
        resource_views_shared(),
    )
    write_summary(inventory, server_eps, client_eps, components, tests)


if __name__ == "__main__":
    main()
