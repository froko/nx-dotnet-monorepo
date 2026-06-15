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
    }
  }
}
EOF
fi

echo ""
echo "Done. Next steps:"
echo "  pnpm restore          # restore NuGet packages"
echo "  nx show project ${NX_PROJECT_NAME}   # verify Nx targets"
