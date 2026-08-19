#!/usr/bin/env python3
"""Build a metadata index for repositories in the chef-cft GitHub organization."""

from __future__ import annotations

import argparse
import base64
import datetime as dt
import json
import os
import re
import subprocess
from collections import Counter
from pathlib import Path
from typing import Any


ORG = "chef-cft"
ROOT = Path(__file__).resolve().parents[2]
JSON_OUTPUT = ROOT / "docs" / "chef-cft-metadata-index.json"
MARKDOWN_OUTPUT = ROOT / "docs" / "chef-cft-metadata-index.md"
USER_REPORTED_TOTAL = 209
TOKEN_PATH = Path.home() / ".github" / "chef-cft.token"

SIGNAL_PATTERNS = {
    "cookbook_metadata": re.compile(r"(^|/)metadata\.rb$", re.I),
    "recipes": re.compile(r"(^|/)recipes/.*\.rb$", re.I),
    "policyfiles": re.compile(r"(^|/)Policyfile(?:\.rb|\.lock\.json)$", re.I),
    "chef_configuration": re.compile(r"(^|/)(?:knife|client|solo)\.rb$", re.I),
    "chef_attributes": re.compile(r"(^|/)attributes/.*\.rb$", re.I),
    "chef_templates": re.compile(r"(^|/)templates/", re.I),
    "chef_custom_resources": re.compile(r"(^|/)resources/.*\.rb$", re.I),
    "inspec_profiles": re.compile(r"(^|/)inspec\.ya?ml$", re.I),
    "inspec_controls": re.compile(r"(^|/)controls/.*\.rb$", re.I),
    "chef_360": re.compile(r"chef[._ -]?360", re.I),
    "node_management": re.compile(r"node[._ -]?management|node[._ -]?enrollment", re.I),
    "courier": re.compile(r"courier", re.I),
    "habitat_plans": re.compile(r"(^|/)(?:habitat/)?plan\.(?:sh|ps1)$", re.I),
    "terraform": re.compile(r"\.tf(?:vars)?$", re.I),
    "packer": re.compile(r"(?:packer|\.pkr\.hcl$)", re.I),
    "cloudformation": re.compile(r"cloudformation|(?:^|/)(?:cfn|template).+\.ya?ml$", re.I),
    "bicep": re.compile(r"\.bicep$", re.I),
    "helm": re.compile(r"(^|/)(?:Chart\.ya?ml|values[^/]*\.ya?ml)$|helm", re.I),
    "kubernetes": re.compile(r"(^|/)(?:k8s|kubernetes)/|kube|ingress\.ya?ml$", re.I),
    "ansible": re.compile(r"(^|/)(?:ansible|playbooks?)/|playbook.*\.ya?ml$", re.I),
    "docker": re.compile(r"(^|/)Dockerfile$|docker-compose", re.I),
    "test_kitchen": re.compile(r"(^|/)\.kitchen\.ya?ml$", re.I),
    "berksfiles": re.compile(r"(^|/)Berksfile(?:\.lock)?$", re.I),
    "chef_workflows": re.compile(r"(^|/)\.github/workflows/.*\.ya?ml$", re.I),
    "documentation": re.compile(r"(^|/)(?:README[^/]*|docs/.*)$", re.I),
    "scripts": re.compile(r"(^|/)(?:scripts?|bin)/", re.I),
}

KEYWORDS = {
    "Chef 360": re.compile(r"chef[\s_-]*360|chef360", re.I),
    "Chef Node Management": re.compile(r"node[\s_-]*management|node[\s_-]*enrollment", re.I),
    "Chef Courier": re.compile(r"\bcourier\b", re.I),
    "Chef DSM": re.compile(r"desktop security mode|desktop security management|\bdsm\b", re.I),
    "Chef Infra": re.compile(r"chef[ -](?:infra|client|server)|cookbook|policyfile|berks", re.I),
    "Chef Automate": re.compile(r"chef automate|automate 2|\ba2\b", re.I),
    "Chef InSpec": re.compile(r"inspec|compliance|audit profile", re.I),
    "Chef Habitat": re.compile(r"habitat|\bhab\b|effortless", re.I),
    "Test Kitchen": re.compile(r"test[ -]kitchen|\.kitchen", re.I),
    "Terraform": re.compile(r"terraform", re.I),
    "Packer": re.compile(r"packer", re.I),
    "AWS": re.compile(r"\baws\b|amazon web services", re.I),
    "Azure": re.compile(r"\bazure\b", re.I),
    "GCP": re.compile(r"\bgcp\b|google cloud", re.I),
    "Windows": re.compile(r"\bwindows\b|powershell", re.I),
    "Linux": re.compile(r"\blinux\b|ubuntu|centos|rhel", re.I),
    "CI/CD": re.compile(r"ci/cd|pipeline|azure devops|github actions", re.I),
}

SENSITIVE = re.compile(
    r"(?:gh[oprsu]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|"
    r"AKIA[0-9A-Z]{16}|Authorization\s*:|password\s*=)",
    re.I,
)


def gh_api(endpoint: str, *fields: str, paginate: bool = False) -> Any:
    command = ["gh", "api", "-X", "GET", endpoint]
    for field in fields:
        command.extend(["-f", field])
    if paginate:
        command.extend(["--paginate", "--slurp"])
    env = os.environ.copy()
    if "GH_TOKEN" not in env and TOKEN_PATH.exists():
        env["GH_TOKEN"] = TOKEN_PATH.read_text(encoding="utf-8").strip()
    result = subprocess.run(command, check=True, capture_output=True, text=True, env=env)
    return json.loads(result.stdout)


def get_readme(repo: str) -> tuple[str | None, str | None, str]:
    try:
        payload = gh_api(f"repos/{ORG}/{repo}/readme")
    except subprocess.CalledProcessError:
        return None, None, ""

    content = base64.b64decode(payload.get("content", "")).decode("utf-8", errors="replace")
    title = None
    excerpt = None
    for raw_line in content.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("<!--") or re.match(r"^\[?!?\[", line):
            continue
        heading = re.match(r"^#{1,6}\s+(.+)$", line)
        if heading and title is None:
            title = clean_markdown(heading.group(1), 120)
            continue
        if line.startswith(("```", "---", "===", "<", "[!")):
            continue
        cleaned = clean_markdown(line, 300)
        if cleaned:
            excerpt = cleaned
            break
    return title, excerpt, content[:100_000]


def clean_markdown(value: str, limit: int) -> str:
    value = re.sub(r"!\[[^]]*]\([^)]*\)", "", value)
    value = re.sub(r"\[([^]]+)]\([^)]*\)", r"\1", value)
    value = re.sub(r"<[^>]+>", "", value)
    value = re.sub(r"[`*_]", "", value)
    value = re.sub(r"https?://\S+", "[link]", value)
    value = re.sub(r"\s+", " ", value).strip(" -|#")
    if SENSITIVE.search(value):
        return "[redacted potentially sensitive README text]"
    return value[:limit].rstrip()


def collect_signals(paths: list[str]) -> dict[str, dict[str, Any]]:
    signals = {}
    for name, pattern in SIGNAL_PATTERNS.items():
        matches = sorted(path for path in paths if pattern.search(path))
        examples = [path if not SENSITIVE.search(path) else "[redacted path]" for path in matches[:12]]
        signals[name] = {"count": len(matches), "examples": examples}
    return signals


def classify(repo: dict[str, Any], paths: list[str], readme_text: str) -> tuple[list[str], list[str], str]:
    signals = collect_signals(paths)
    corpus = " ".join(
        [repo["name"], repo.get("description") or "", readme_text, " ".join(paths[:5000])]
    )
    keywords = sorted(name for name, pattern in KEYWORDS.items() if pattern.search(corpus))
    categories = []

    if "Chef 360" in keywords or signals["chef_360"]["count"]:
        categories.append("Chef 360")
    if "Chef Node Management" in keywords or signals["node_management"]["count"]:
        categories.append("Node Management")
    if "Chef Courier" in keywords or signals["courier"]["count"]:
        categories.append("Chef Courier")
    if signals["cookbook_metadata"]["count"] or signals["recipes"]["count"] or signals["policyfiles"]["count"]:
        categories.append("Chef Infra")
    if signals["inspec_profiles"]["count"] or signals["inspec_controls"]["count"]:
        categories.append("InSpec and Compliance")
    if signals["habitat_plans"]["count"] or "Chef Habitat" in keywords:
        categories.append("Chef Habitat")
    if "Chef Automate" in keywords:
        categories.append("Chef Automate")
    if (
        signals["terraform"]["count"]
        or signals["packer"]["count"]
        or signals["cloudformation"]["count"]
        or signals["bicep"]["count"]
    ):
        categories.append("Infrastructure as Code")
    if signals["helm"]["count"] or signals["kubernetes"]["count"]:
        categories.append("Kubernetes and Helm")
    if "CI/CD" in keywords:
        categories.append("CI/CD")
    if re.search(r"workshop|training|tutorial|demo|example|poc|lab", corpus, re.I):
        categories.append("Training and Demonstration")
    if not categories:
        categories.append("Supporting or Application Content")

    direct = (
        signals["cookbook_metadata"]["count"]
        + signals["recipes"]["count"]
        + signals["policyfiles"]["count"]
        + signals["inspec_profiles"]["count"]
        + signals["inspec_controls"]["count"]
    )
    related = sum(
        signals[name]["count"]
        for name in [
            "habitat_plans",
            "terraform",
            "packer",
            "cloudformation",
            "bicep",
            "helm",
            "kubernetes",
            "ansible",
            "docker",
        ]
    )
    relevance = (
        "direct"
        if direct or "Chef 360" in categories or "Node Management" in categories or "Chef Courier" in categories
        else "related"
        if related or any(k.startswith("Chef ") for k in keywords)
        else "general"
    )
    return categories, keywords, relevance


def freshness(repo: dict[str, Any], now: dt.datetime) -> str:
    pushed = dt.datetime.fromisoformat(repo["pushed_at"].replace("Z", "+00:00"))
    age = (now - pushed).days
    if repo["archived"]:
        return "archived"
    if age <= 730:
        return "active-within-2-years"
    return "stale-over-2-years"


def summarize_use(repo: dict[str, Any]) -> str:
    categories = repo["categories"]
    if repo.get("description"):
        return repo["description"]
    if "Chef Infra" in categories:
        return "Chef Infra cookbook, recipe, or Policyfile reference content."
    if "InSpec and Compliance" in categories:
        return "Chef InSpec profile or compliance reference content."
    if "Chef Habitat" in categories:
        return "Chef Habitat plan or demonstration content."
    if "Infrastructure as Code" in categories:
        return "Infrastructure-as-code reference content."
    return repo.get("readme_excerpt") or "No concise repository description was available."


def build_index() -> dict[str, Any]:
    now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
    org = gh_api(f"orgs/{ORG}")
    pages = gh_api(f"orgs/{ORG}/repos", "type=all", "per_page=100", paginate=True)
    source_repos = [repo for page in pages for repo in page]
    repositories = []
    failures = []

    for position, source in enumerate(sorted(source_repos, key=lambda item: item["name"].lower()), start=1):
        name = source["name"]
        print(f"[{position}/{len(source_repos)}] Indexing {ORG}/{name}")
        try:
            tree = gh_api(f"repos/{ORG}/{name}/git/trees/{source['default_branch']}", "recursive=1")
        except subprocess.CalledProcessError as error:
            failures.append({"repository": source["full_name"], "stage": "tree", "status": error.returncode})
            tree = {"tree": [], "sha": None, "truncated": False}
        paths = [item["path"] for item in tree.get("tree", []) if item["type"] == "blob"]
        readme_title, readme_excerpt, readme_content = get_readme(name)
        readme_text = " ".join(value for value in [readme_title, readme_excerpt, readme_content] if value)
        signals = collect_signals(paths)
        categories, keywords, relevance = classify(source, paths, readme_text)

        item = {
            "name": name,
            "full_name": source["full_name"],
            "url": source["html_url"],
            "description": clean_markdown(source["description"], 300) if source.get("description") else None,
            "visibility": source["visibility"],
            "archived": source["archived"],
            "fork": source["fork"],
            "default_branch": source["default_branch"],
            "tree_sha": tree.get("sha"),
            "tree_truncated": tree.get("truncated", False),
            "created_at": source["created_at"],
            "updated_at": source["updated_at"],
            "pushed_at": source["pushed_at"],
            "freshness": freshness(source, now),
            "primary_language": source.get("language"),
            "license": (source.get("license") or {}).get("spdx_id"),
            "size_kb": source["size"],
            "stars": source["stargazers_count"],
            "forks": source["forks_count"],
            "open_issues": source["open_issues_count"],
            "readme_title": readme_title,
            "readme_excerpt": readme_excerpt,
            "categories": categories,
            "keywords": keywords,
            "relevance": relevance,
            "signals": signals,
            "file_count": len(paths),
        }
        item["usefulness"] = summarize_use(item)
        repositories.append(item)

    category_counts = Counter(category for repo in repositories for category in repo["categories"])
    relevance_counts = Counter(repo["relevance"] for repo in repositories)
    freshness_counts = Counter(repo["freshness"] for repo in repositories)
    language_counts = Counter(repo["primary_language"] or "Unknown" for repo in repositories)
    keyword_counts = Counter(keyword for repo in repositories for keyword in repo["keywords"])

    return {
        "schema_version": 3,
        "generated_at": now.isoformat().replace("+00:00", "Z"),
        "organization": {
            "login": org["login"],
            "name": org["name"],
            "url": org["html_url"],
            "description": org["description"],
            "public_repository_count": org["public_repos"],
            "private_repository_count": sum(repo["visibility"] == "private" for repo in source_repos),
            "internal_repository_count": sum(repo["visibility"] == "internal" for repo in source_repos),
            "visible_repository_count": len(source_repos),
            "expected_repository_count": USER_REPORTED_TOTAL,
        },
        "coverage": {
            "scope": "all repositories visible to the SAML-authorized token",
            "indexed_repository_count": len(repositories),
            "metadata_complete": len(repositories) == len(source_repos),
            "tree_failure_count": len(failures),
            "limitations": [
                "Repository content is represented by paths, structural signals, and sanitized README summaries; full source content is not copied.",
                "Recursive Git trees marked truncated by GitHub provide partial structural coverage.",
            ],
        },
        "summary": {
            "category_counts": dict(sorted(category_counts.items())),
            "relevance_counts": dict(sorted(relevance_counts.items())),
            "freshness_counts": dict(sorted(freshness_counts.items())),
            "primary_language_counts": dict(language_counts.most_common()),
            "keyword_counts": dict(keyword_counts.most_common()),
        },
        "failures": failures,
        "repositories": repositories,
    }


def render_markdown(index: dict[str, Any]) -> str:
    summary = index["summary"]
    repos = index["repositories"]
    direct = sorted(
        (repo for repo in repos if repo["relevance"] == "direct"),
        key=lambda repo: (repo["freshness"] == "archived", repo["name"].lower()),
    )
    related = sorted(
        (repo for repo in repos if repo["relevance"] == "related"),
        key=lambda repo: (repo["freshness"] == "archived", repo["name"].lower()),
    )
    chef_360 = sorted(
        (
            repo
            for repo in repos
            if "Chef 360" in repo["categories"]
            or "Node Management" in repo["categories"]
            or "Chef Courier" in repo["categories"]
        ),
        key=lambda repo: (repo["freshness"] == "archived", repo["name"].lower()),
    )

    lines = [
        "# Chef CFT Organization Metadata Index",
        "",
        f"Generated {index['generated_at']} from [{ORG}](https://github.com/{ORG}).",
        "",
        "The machine-readable companion is [`docs/chef-cft-metadata-index.json`](chef-cft-metadata-index.json).",
        "",
        "## Coverage",
        "",
        f"- Repositories indexed: **{index['coverage']['indexed_repository_count']}** of **{index['organization']['visible_repository_count']}** visible to the SAML-authorized token.",
        f"- Visibility: **{index['organization']['public_repository_count']}** public, **{index['organization']['private_repository_count']}** private, **{index['organization']['internal_repository_count']}** internal.",
        f"- Repository tree failures: **{index['coverage']['tree_failure_count']}**.",
        "- Stored data is limited to repository metadata, file-path signals, and sanitized README summaries. Full repository content is not copied.",
        "",
        "## Summary",
        "",
        f"- Direct Chef Infra or InSpec references: **{summary['relevance_counts'].get('direct', 0)}**.",
        f"- Related Habitat, Automate, or infrastructure references: **{summary['relevance_counts'].get('related', 0)}**.",
        f"- Archived repositories: **{summary['freshness_counts'].get('archived', 0)}**.",
        f"- Active within two years: **{summary['freshness_counts'].get('active-within-2-years', 0)}**.",
        "",
        "## Category Counts",
        "",
        "| Category | Repositories |",
        "|---|---:|",
    ]
    for category, count in summary["category_counts"].items():
        lines.append(f"| {category} | {count} |")

    def add_repo_table(title: str, selected: list[dict[str, Any]]) -> None:
        lines.extend(
            [
                "",
                f"## {title}",
                "",
                "| Repository | Visibility | Categories | Status | Useful content |",
                "|---|---|---|---|---|",
            ]
        )
        for repo in selected:
            use = repo["usefulness"].replace("|", "\\|")
            categories = ", ".join(repo["categories"])
            lines.append(
                f"| [`{repo['name']}`]({repo['url']}) | {repo['visibility']} | {categories} | {repo['freshness']} | {use} |"
            )

    add_repo_table("Chef 360, Node Management, and Courier", chef_360)
    add_repo_table("Direct Chef References", direct)
    add_repo_table("Related Platform References", related)

    lines.extend(
        [
            "",
            "## Search Examples",
            "",
            "```bash",
            "# Chef 360 mentions found in indexed README/path metadata",
            "jq -r '.repositories[] | select(.keywords | index(\"Chef 360\")) | .full_name' docs/chef-cft-metadata-index.json",
            "",
            "# Repositories containing Policyfiles",
            "jq -r '.repositories[] | select(.signals.policyfiles.count > 0) | .full_name' docs/chef-cft-metadata-index.json",
            "",
            "# InSpec profiles and representative paths",
            "jq -r '.repositories[] | select(.signals.inspec_profiles.count > 0) | [.full_name, (.signals.inspec_profiles.examples | join(\", \"))] | @tsv' docs/chef-cft-metadata-index.json",
            "",
            "# Recently active, non-archived references",
            "jq -r '.repositories[] | select(.freshness == \"active-within-2-years\") | [.full_name, .pushed_at, (.categories | join(\", \"))] | @tsv' docs/chef-cft-metadata-index.json",
            "```",
            "",
            "## Refresh",
            "",
            "```bash",
            "python3 scripts/content/chef_cft_org_index.py build",
            "```",
            "",
            "The generator uses the SAML-authorized token at `~/.github/chef-cft.token` when `GH_TOKEN` is not already set. It never writes the token value to either index.",
        ]
    )
    return "\n".join(lines) + "\n"


def query_index(args: argparse.Namespace) -> None:
    index = json.loads(JSON_OUTPUT.read_text(encoding="utf-8"))
    matches = index["repositories"]

    if args.category:
        matches = [repo for repo in matches if args.category.lower() in {item.lower() for item in repo["categories"]}]
    if args.keyword:
        matches = [repo for repo in matches if args.keyword.lower() in {item.lower() for item in repo["keywords"]}]
    if args.visibility:
        matches = [repo for repo in matches if repo["visibility"] == args.visibility]
    if args.freshness:
        matches = [repo for repo in matches if repo["freshness"] == args.freshness]
    if args.signal:
        matches = [repo for repo in matches if repo["signals"].get(args.signal, {}).get("count", 0) > 0]
    if args.q:
        term = args.q.lower()
        matches = [
            repo
            for repo in matches
            if term
            in " ".join(
                [
                    repo["name"],
                    repo.get("description") or "",
                    repo.get("readme_title") or "",
                    repo.get("readme_excerpt") or "",
                    " ".join(repo["categories"]),
                    " ".join(repo["keywords"]),
                ]
            ).lower()
        ]

    if args.json:
        print(json.dumps(matches, indent=2))
        return

    for repo in matches:
        print(
            "\t".join(
                [
                    repo["full_name"],
                    repo["visibility"],
                    repo["freshness"],
                    ", ".join(repo["categories"]),
                    repo["usefulness"],
                ]
            )
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["build", "query"])
    parser.add_argument("--category")
    parser.add_argument("--keyword")
    parser.add_argument("--visibility", choices=["public", "private", "internal"])
    parser.add_argument(
        "--freshness",
        choices=["active-within-2-years", "stale-over-2-years", "archived"],
    )
    parser.add_argument("--signal", choices=sorted(SIGNAL_PATTERNS))
    parser.add_argument("--q")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    if args.command == "build":
        index = build_index()
        JSON_OUTPUT.write_text(json.dumps(index, indent=2) + "\n", encoding="utf-8")
        MARKDOWN_OUTPUT.write_text(render_markdown(index), encoding="utf-8")
        JSON_OUTPUT.chmod(0o600)
        MARKDOWN_OUTPUT.chmod(0o600)
        print(f"Wrote {JSON_OUTPUT}")
        print(f"Wrote {MARKDOWN_OUTPUT}")
    else:
        query_index(args)


if __name__ == "__main__":
    main()
