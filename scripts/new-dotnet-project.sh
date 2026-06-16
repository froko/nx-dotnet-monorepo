#!/usr/bin/env bash
#
# Create a new .NET project in this monorepo and wire it up for Nx.
#
# This is a thin wrapper around `dotnet new` that, in addition to scaffolding the
# project, drops in a `project.json` so the project gets the workspace-standard
# Nx targets (a `format` target for every project, plus a coverage-enabled
# `test` target for test projects).
#
# Usage:
#   scripts/new-dotnet-project.sh <template> -o <output-dir> -n <project-name> [extra dotnet args...]
#
# Examples:
#   scripts/new-dotnet-project.sh classlib -o libs/my-lib       -n MyLib
#   scripts/new-dotnet-project.sh webapi   -o apps/my-api       -n MyApi
#   scripts/new-dotnet-project.sh xunit    -o libs/my-lib-tests -n MyLib.Tests
#
# Whether a project is treated as a "test project" is detected from the template
# (xunit/nunit/mstest) or an output dir ending in `-tests`. Override with the
# TEST_PROJECT env var (TEST_PROJECT=1 / TEST_PROJECT=0).
#
set -euo pipefail

# --- locate workspace root (the dir containing this script's parent) ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <template> -o <output-dir> -n <project-name> [extra dotnet args...]" >&2
  exit 1
fi

TEMPLATE="$1"
shift

# --- parse the args we care about, pass everything through to `dotnet new` ----
OUTPUT_DIR=""
PROJECT_NAME=""
DOTNET_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      OUTPUT_DIR="$2"
      DOTNET_ARGS+=("$1" "$2")
      shift 2
      ;;
    -n|--name)
      PROJECT_NAME="$2"
      DOTNET_ARGS+=("$1" "$2")
      shift 2
      ;;
    *)
      DOTNET_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ -z "$OUTPUT_DIR" ]]; then
  echo "error: an output directory (-o <dir>) is required" >&2
  exit 1
fi

# --- scaffold the .NET project ------------------------------------------------
echo "==> dotnet new $TEMPLATE ${DOTNET_ARGS[*]}"
dotnet new "$TEMPLATE" "${DOTNET_ARGS[@]}"

# --- tidy up the generated .csproj --------------------------------------------
# `dotnet new` emits properties that are already defined globally in the root
# Directory.Build.props (TargetFramework, ImplicitUsings, Nullable) and pins
# package versions inline on each PackageReference. This repo uses Central
# Package Management (Directory.Packages.props), so inline versions must instead
# live there as <PackageVersion> entries.
#
# This step rewrites the freshly generated .csproj to:
#   * drop properties that are inherited from Directory.Build.props, and
#   * move every "PackageReference ... Version=..." into Directory.Packages.props
#     (as a PackageVersion) and strip the inline Version attribute.
echo "==> tidying generated .csproj (inherit Directory.Build.props + CPM)"
PACKAGES_PROPS="$WORKSPACE_ROOT/Directory.Packages.props" \
PROJECT_OUTPUT_DIR="$WORKSPACE_ROOT/$OUTPUT_DIR" \
  python3 - <<'PY'
import os
import re
import sys
import xml.etree.ElementTree as ET

project_dir = os.environ["PROJECT_OUTPUT_DIR"]
packages_props = os.environ["PACKAGES_PROPS"]

# Properties that are defined centrally in the root Directory.Build.props and
# therefore must not be repeated in individual project files.
INHERITED_PROPERTIES = {"TargetFramework", "ImplicitUsings", "Nullable"}

# Locate the .csproj that dotnet new just created in the output directory.
csprojs = [
    os.path.join(project_dir, f)
    for f in os.listdir(project_dir)
    if f.endswith((".csproj", ".fsproj", ".vbproj"))
]
if not csprojs:
    sys.exit(0)
csproj = csprojs[0]

with open(csproj, "r", encoding="utf-8") as fh:
    original = fh.read()

# --- 1. strip inherited properties --------------------------------------------
# Remove lines like "<TargetFramework>net10.0</TargetFramework>".
lines = original.splitlines()
kept = []
for line in lines:
    m = re.match(r"\s*<([A-Za-z0-9_]+)>.*</\1>\s*$", line)
    if m and m.group(1) in INHERITED_PROPERTIES:
        continue
    kept.append(line)
content = "\n".join(kept)

# Drop any PropertyGroup that is now empty (only whitespace between the tags).
# Consume the group's own trailing newline but leave the next line's
# indentation untouched.
content = re.sub(
    r"[ \t]*<PropertyGroup>[ \t\r\n]*</PropertyGroup>[ \t]*\r?\n?",
    "",
    content,
)

# Collapse 3+ blank lines that may result from the removals down to one.
content = re.sub(r"\n{3,}", "\n\n", content)

# --- 2. migrate inline PackageReference versions to CPM -----------------------
# Match: <PackageReference Include="X" Version="Y" />  (attr order independent).
pkg_versions = {}


def strip_version(match):
    tag = match.group(0)
    inc = re.search(r'Include="([^"]+)"', tag)
    ver = re.search(r'Version="([^"]+)"', tag)
    if inc and ver:
        pkg_versions[inc.group(1)] = ver.group(1)
    # Remove the Version="..." attribute (and the surrounding whitespace).
    return re.sub(r'\s+Version="[^"]+"', "", tag)


content = re.sub(r"<PackageReference\b[^>]*?/>", strip_version, content)
content = re.sub(
    r"<PackageReference\b[^>]*?>",
    lambda m: re.sub(r'\s+Version="[^"]+"', "", m.group(0))
    if "Version=" in m.group(0)
    else m.group(0),
    content,
)
# Capture versions from any non-self-closing PackageReference tags too.
for m in re.finditer(r"<PackageReference\b[^>]*?>", original):
    inc = re.search(r'Include="([^"]+)"', m.group(0))
    ver = re.search(r'Version="([^"]+)"', m.group(0))
    if inc and ver:
        pkg_versions.setdefault(inc.group(1), ver.group(1))

if not content.endswith("\n"):
    content += "\n"

with open(csproj, "w", encoding="utf-8") as fh:
    fh.write(content)

# --- 3. record the package versions centrally ---------------------------------
if pkg_versions:
    tree = ET.parse(packages_props)
    root = tree.getroot()

    # Find (or create) an ItemGroup to hold the PackageVersion entries.
    item_group = root.find("ItemGroup")
    if item_group is None:
        item_group = ET.SubElement(root, "ItemGroup")

    existing = {
        el.get("Include")
        for el in root.iter("PackageVersion")
        if el.get("Include")
    }
    added = []
    for name, version in sorted(pkg_versions.items()):
        if name in existing:
            continue
        el = ET.SubElement(item_group, "PackageVersion")
        el.set("Include", name)
        el.set("Version", version)
        added.append(f"{name} {version}")

    if added:
        ET.indent(tree, space="  ")
        tree.write(packages_props, encoding="unicode", xml_declaration=False)
        # ElementTree writes without a trailing newline; add one for cleanliness.
        with open(packages_props, "r", encoding="utf-8") as fh:
            data = fh.read()
        if not data.endswith("\n"):
            with open(packages_props, "a", encoding="utf-8") as fh:
                fh.write("\n")
        print(
            "    added PackageVersion entries to Directory.Packages.props: "
            + ", ".join(added)
        )
PY

# --- derive the Nx project name & relative depth ------------------------------
# Nx project name = the output directory's basename (matches the existing
# sample-lib / sample-lib-tests convention).
NX_PROJECT_NAME="$(basename "$OUTPUT_DIR")"

# Relative path from the project dir back to the workspace root, used for the
# `$schema` reference (e.g. libs/my-lib -> ../../, apps/group/my-api -> ../../../).
DEPTH="$(echo "$OUTPUT_DIR" | tr '/' '\n' | grep -c .)"
SCHEMA_PREFIX=""
for ((i = 0; i < DEPTH; i++)); do
  SCHEMA_PREFIX+="../"
done

# --- decide whether this is a test project ------------------------------------
is_test_project() {
  if [[ -n "${TEST_PROJECT:-}" ]]; then
    [[ "$TEST_PROJECT" == "1" || "$TEST_PROJECT" == "true" ]]
    return
  fi
  case "$TEMPLATE" in
    xunit|xunit3|nunit|mstest) return 0 ;;
  esac
  [[ "$NX_PROJECT_NAME" == *-tests || "$NX_PROJECT_NAME" == *-test ]]
}

PROJECT_JSON="$WORKSPACE_ROOT/$OUTPUT_DIR/project.json"

# --- write the project.json from the appropriate template ---------------------
if is_test_project; then
  echo "==> writing test project.json -> $OUTPUT_DIR/project.json"
  cat > "$PROJECT_JSON" <<EOF
{
  "\$schema": "${SCHEMA_PREFIX}node_modules/nx/schemas/project-schema.json",
  "name": "${NX_PROJECT_NAME}",
  "targets": {
    "format": {
      "executor": "nx:run-commands",
      "options": {
        "command": "dotnet format",
        "cwd": "{projectRoot}"
      }
    },
    "lint": {
      "executor": "nx:run-commands",
      "cache": true,
      "dependsOn": ["restore"],
      "options": {
        "command": "dotnet format --verify-no-changes --no-restore",
        "cwd": "{projectRoot}"
      }
    },
    "test": {
      "executor": "nx:run-commands",
      "cache": true,
      "dependsOn": ["build"],
      "outputs": ["{workspaceRoot}/dist/coverage/{projectName}"],
      "options": {
        "cwd": "{workspaceRoot}",
        "command": "dotnet test {projectRoot} --no-build --no-restore --settings coverage.runsettings --results-directory dist/coverage/{projectName}"
      }
    }
  }
}
EOF
else
  echo "==> writing project.json -> $OUTPUT_DIR/project.json"
  cat > "$PROJECT_JSON" <<EOF
{
  "\$schema": "${SCHEMA_PREFIX}node_modules/nx/schemas/project-schema.json",
  "name": "${NX_PROJECT_NAME}",
  "targets": {
    "format": {
      "executor": "nx:run-commands",
      "options": {
        "command": "dotnet format",
        "cwd": "{projectRoot}"
      }
    },
    "lint": {
      "executor": "nx:run-commands",
      "cache": true,
      "dependsOn": ["restore"],
      "options": {
        "command": "dotnet format --verify-no-changes --no-restore",
        "cwd": "{projectRoot}"
      }
    }
  }
}
EOF
fi

echo ""
echo "Done. Next steps:"
echo "  pnpm restore          # restore NuGet packages"
echo "  nx show project ${NX_PROJECT_NAME}   # verify Nx targets"
