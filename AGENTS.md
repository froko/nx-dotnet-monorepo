# AI assistant instructions

Vendor-neutral guidance for AI coding assistants working in this repository.
This file follows the [AGENTS.md](https://agents.md) convention and is read
automatically by several assistants (OpenCode, Cursor, Aider, Gemini CLI, and
others). Tools that look for their own instruction file (e.g. Claude Code's
`CLAUDE.md` or GitHub Copilot's `.github/copilot-instructions.md`) can point to
this file instead of duplicating its contents.

For full project documentation, see [`README.md`](./README.md).

## Creating new .NET projects

**Always create new .NET projects with the wrapper script, not `dotnet new`
directly.**

```bash
# Class library  -> project.json with a `format` target
scripts/new-dotnet-project.sh classlib -o libs/my-lib -n MyLib

# Application     -> project.json with a `format` target
scripts/new-dotnet-project.sh webapi -o apps/my-api -n MyApi

# Test project    -> project.json with `format` + coverage `test` target
scripts/new-dotnet-project.sh xunit -o libs/my-lib-tests -n MyLib.Tests
```

The script runs the same `dotnet new` command and then adds a workspace-standard
`project.json` so the project picks up the shared Nx targets automatically. Using
`dotnet new` on its own skips this and produces a project without the expected
`format`/`test` targets.

- Test projects are detected from the template (`xunit`/`nunit`/`mstest`) or an
  output directory ending in `-tests`. Override with `TEST_PROJECT=1` /
  `TEST_PROJECT=0`.
- Any extra arguments are passed straight through to `dotnet new`.
- Place applications under `apps/` and libraries under `libs/`.
- After creating (or pulling) .NET projects, run `pnpm restore` once.

## Conventions

- This is an Nx + pnpm monorepo containing .NET projects and an Astro docs site.
- Shared .NET defaults (`TargetFramework`, `Nullable`, `ImplicitUsings`, central
  `dist/` output) live in the root `Directory.Build.props` — do not duplicate
  them per project.
- Test coverage settings are centralized in `coverage.runsettings`; the `test`
  target writes a Cobertura report to `dist/coverage/<project-name>`.
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/).
- Common tasks: `pnpm build`, `pnpm test`, `pnpm lint`, `pnpm format`,
  `pnpm restore` (each maps to an `nx run-many` target).
