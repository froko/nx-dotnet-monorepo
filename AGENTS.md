# AI assistant instructions

Vendor-neutral guidance for AI coding assistants working in this repository.
This file follows the [AGENTS.md](https://agents.md) convention and is read
automatically by several assistants (OpenCode, Cursor, Aider, Gemini CLI, and
others). Tools that look for their own instruction file (e.g. Claude Code's
`CLAUDE.md` or GitHub Copilot's `.github/copilot-instructions.md`) can point to
this file instead of duplicating its contents.

For full project documentation, see [`README.md`](./README.md).

## Workspace layout

This template supports two use cases. Choose folders based on what the repo is
building, and make sure the chosen folders are registered in
`pnpm-workspace.yaml`:

- **Applications** (default): `apps/` for deployable applications, `libs/` for
  internal libraries consumed within the repo. `apps/*` and `libs/*` are already
  registered.
- **Publishable NuGet libraries**: `packages/` for libraries that are packed and
  published as NuGet packages, `examples/` for sample apps that consume them.
  Register `packages/*` and `examples/*` in `pnpm-workspace.yaml` before adding
  projects there.

## Converting to a publishable NuGet library workspace

When the user asks to convert the workspace from the default application layout
(`apps/` + `libs/`) to a publishable NuGet library layout (`packages/` +
`examples/`), perform **all** of the following steps. The folder names appear in
several places — missing any one of them leaves the workspace in an inconsistent
state.

1. **`pnpm-workspace.yaml`** — replace the `apps/*` and `libs/*` globs with
   `packages/*` and `examples/*` (keep `docs`):

   ```yaml
   packages:
     - 'packages/*'
     - 'examples/*'
     - 'docs'
   ```

2. **`.prettierignore`** — replace the `apps` and `libs` lines with `packages`
   and `examples` (keep `docs` and the other entries) so the new folders are
   ignored exactly as the old ones were:

   ```
   packages
   examples
   docs

   CHANGELOG.md
   pnpm-lock.yaml
   ```

3. **Move existing .NET projects.** Relocate any libraries from `libs/` into
   `packages/` and any applications from `apps/` into `examples/` (the sample
   ships in `libs/sample-lib` and `libs/sample-lib-tests`). Use `git mv` so
   history is preserved, then fix the relative `$schema` path and any
   `ProjectReference`/`reference` paths in the moved `project.json` and
   `.csproj` files. If the user prefers a clean slate, delete the samples and
   scaffold fresh projects with the wrapper script instead.

4. **Make libraries packable.** For each project under `packages/`, set the
   NuGet metadata (`PackageId`, `Authors`, `Description`, …) and ensure
   `<IsPackable>true</IsPackable>` (the default for class libraries; keep test
   projects `IsPackable=false`). Shared metadata can go centrally in
   `Directory.Build.props`. See
   [Publishing NuGet packages](#publishing-nuget-packages).

5. **Remove now-empty `apps/`/`libs/` folders** once their projects have moved.

6. **Restore and verify.** Run `pnpm restore`, then `pnpm build`, `pnpm test`,
   and `pnpm format` to confirm the workspace is consistent after the move.

After the conversion, create new projects in `packages/` (libraries/tests) and
`examples/` (sample apps), not `apps/`/`libs/`.

## Creating new .NET projects

**Always create new .NET projects with the wrapper script, not `dotnet new`
directly.**

```bash
# Application workspace
scripts/new-dotnet-project.sh classlib -o libs/my-lib -n MyLib              # internal library
scripts/new-dotnet-project.sh webapi   -o apps/my-api -n MyApi              # application
scripts/new-dotnet-project.sh xunit    -o libs/my-lib-tests -n MyLib.Tests  # test project

# Publishable NuGet library workspace
scripts/new-dotnet-project.sh classlib -o packages/my-package -n MyPackage                # publishable package
scripts/new-dotnet-project.sh xunit    -o packages/my-package-tests -n MyPackage.Tests    # test project
scripts/new-dotnet-project.sh console  -o examples/my-package-sample -n MyPackage.Sample  # sample app
```

The script runs the same `dotnet new` command and then:

1. adds a workspace-standard `project.json` so the project picks up the shared
   Nx targets automatically (a `format` and a `lint` target for every project,
   plus a coverage-enabled `test` target for test projects), and
2. tidies the generated `.csproj` so it matches the repo conventions (see
   below).

Using `dotnet new` on its own skips both steps and produces a project without
the expected `format`/`lint`/`test` targets and with settings that conflict with
the repo-wide defaults.

### How the generated `.csproj` is tidied

`dotnet new` emits properties that are already defined globally and pins package
versions inline, neither of which fits this repo. The script rewrites the
`.csproj` to:

- **Inherit from `Directory.Build.props`** — properties that are set centrally
  (`TargetFramework`, `ImplicitUsings`, `Nullable`) are removed from the
  `.csproj` so they are inherited rather than duplicated. An empty
  `<PropertyGroup>` left behind is dropped.
- **Use Central Package Management (CPM)** — the repo enables CPM via
  `Directory.Packages.props` (`ManagePackageVersionsCentrally` is `true`). The
  script strips the inline `Version="…"` from every `<PackageReference>` and
  records it as a `<PackageVersion>` entry in `Directory.Packages.props`. With
  CPM enabled, a `<PackageReference>` that still carries a `Version` fails to
  restore (`NU1008`).

When editing or adding .NET projects by hand, follow the same rules: never
re-declare the globally-inherited properties, and never put a `Version` on a
`<PackageReference>` — add/update the `<PackageVersion>` in
`Directory.Packages.props` instead.

- Test projects are detected from the template (`xunit`/`nunit`/`mstest`) or an
  output directory ending in `-tests`. Override with `TEST_PROJECT=1` /
  `TEST_PROJECT=0`.
- Any extra arguments are passed straight through to `dotnet new`.
- Place projects in the folder that matches the use case (see Workspace layout).
- After creating (or pulling) .NET projects, run `pnpm restore` once.

## Publishing NuGet packages

For the publishable-library use case, every library has a `pack` target from the
`@nx/dotnet` plugin (`nx pack <project>` or `nx run-many -t pack`) that builds a
`.nupkg` into `dist/`. Set package metadata (`PackageId`, `Authors`,
`Description`, …) in the `.csproj` or centrally in `Directory.Build.props`.

## Conventions

- This is an Nx + pnpm monorepo containing .NET projects and an Astro docs site.
- Shared .NET defaults (`TargetFramework`, `Nullable`, `ImplicitUsings`, central
  `dist/` output) live in the root `Directory.Build.props` — do not duplicate
  them per project.
- Test coverage settings are centralized in `coverage.runsettings`; the `test`
  target writes a Cobertura report to `dist/coverage/<project-name>`.
- For .NET projects the `format` target runs `dotnet format` (writes fixes) and
  the `lint` target runs `dotnet format --verify-no-changes --no-restore` (fails
  if the code is not formatted). Both live in each project's `project.json`.
- Commit messages follow
  [Conventional Commits](https://www.conventionalcommits.org/).
- Common tasks: `pnpm build`, `pnpm test`, `pnpm lint`, `pnpm format`,
  `pnpm restore` (each maps to an `nx run-many` target).
