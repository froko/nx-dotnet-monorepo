# Nx .NET/JS MonoRepo starter project

A solid starting point for your new Nx based mixed .NET/JavaScript MonoRepo.

## What's included?

- pnpm workspace
- Nx
- .NET support via the official
  [`@nx/dotnet`](https://nx.dev/docs/technologies/dotnet/introduction) plugin
  (targeting `net10.0`, centralized build output to `dist/`)
- semantic-release
- GitHub Actions for linting PR title with Conventional Commit rules, CI &
  Release
- Arc42 documentation template with Astro Starlight

## Prerequisites

- [Node.js](https://nodejs.org/) (see `.nvmrc`)
- [pnpm](https://pnpm.io/)
- [.NET SDK 10.0+](https://dotnet.microsoft.com/) (required by the `@nx/dotnet`
  plugin)

## Getting Started

1. Run the following command to create a new project-name

   `npx degit https://github.com/froko/nx-dotnet-monorepo <project-name>`

2. Run `pnpm install`

3. Change into the project directory and create a first commit with

   ```bash
   git init
   git add .
   git commit -m "chore: initial commit"
   ```

4. Make it yours by changing some information in the following files
   - `README.json`
   - `package.json` (name, description, author, repository url)
   - `docs/astro.config.json` (title, social url)
   - `docs/src/content/docs/index.mdx` (title)

5. Commit your changes

   ```bash
   git add .
   git commit -m "chore: update project information"
   ```

6. Start adding projects and libraries

## Available commands on the root level

- `pnpm install` - Install all dependencies
- `pnpm format` - Format all projects
- `pnpm lint` - Lint all projects
- `pnpm build` - Build all projects
- `pnpm test` - Run all tests
- `pnpm restore` - Restore NuGet packages for all .NET projects
- `pnpm affected` - Lint, Build & Test all affected projects
- `pnpm all` - Lint, Build & Test all projects

## Workspace structure

This template supports two common use cases. Pick the layout that matches your
goal — or mix them, since both are just folders of Nx projects.

### Use case 1 — Applications (default)

Building one or more deployable applications backed by shared libraries:

- `apps/` — deployable applications (web APIs, services, CLIs, …)
- `libs/` — internal libraries consumed by the apps in this repo

This is the layout the template ships with (`apps/*` and `libs/*` are already
registered in `pnpm-workspace.yaml`).

### Use case 2 — Publishable NuGet libraries

Building a library or a set of libraries to be published as NuGet packages, with
runnable samples that demonstrate them:

- `packages/` — libraries that are packed and published as NuGet packages
- `examples/` — sample apps that consume the packages locally

To enable this layout, register the folders in `pnpm-workspace.yaml`:

```yaml
packages:
  - 'apps/*'
  - 'libs/*'
  - 'packages/*'
  - 'examples/*'
  - 'docs'
```

Projects under `packages/` are typically packable — set
`<IsPackable>true</IsPackable>` (the default for class libraries) and run
`nx pack <project>` to produce a `.nupkg`. The `@nx/dotnet` plugin exposes a
`pack` target for every library.

### Customizing the layout

You can add more directories or rename the default ones by editing
`pnpm-workspace.yaml`. Nx automatically adheres to these changes — any
`.csproj`, `.fsproj` or `.vbproj` found under a registered folder is picked up.

## Adding .NET projects

.NET projects are created with the standard `dotnet new` CLI. The `@nx/dotnet`
plugin automatically detects any `.csproj`, `.fsproj` or `.vbproj` file and adds
the corresponding Nx targets (`build`, `test`, `restore`, `clean`, `publish`,
`pack`, `run`, `watch`).

For an **application** workspace (`apps/` + `libs/`):

```bash
# Create a web API application
dotnet new webapi -o apps/my-api -n MyApi

# Create a class library
dotnet new classlib -o libs/my-lib -n MyLib

# Create a test project
dotnet new xunit -o libs/my-lib-tests -n MyLib.Tests

# Add a project reference
dotnet add libs/my-lib-tests/MyLib.Tests.csproj reference libs/my-lib/MyLib.csproj
```

For a **publishable NuGet library** workspace (`packages/` + `examples/`):

```bash
# Create a library to be packed & published
dotnet new classlib -o packages/my-package -n MyPackage

# Create a test project for it
dotnet new xunit -o packages/my-package-tests -n MyPackage.Tests

# Create a sample app that consumes the package
dotnet new console -o examples/my-package-sample -n MyPackage.Sample

# Add project references
dotnet add packages/my-package-tests/MyPackage.Tests.csproj reference packages/my-package/MyPackage.csproj
dotnet add examples/my-package-sample/MyPackage.Sample.csproj reference packages/my-package/MyPackage.csproj
```

> Remember to register `packages/*` and `examples/*` in `pnpm-workspace.yaml`
> (see [Workspace structure](#workspace-structure)) before adding projects
> there.

### Recommended: scaffold with the wrapper script

Use `scripts/new-dotnet-project.sh` instead of calling `dotnet new` directly. It
runs the same `dotnet new` command and then drops in a workspace-standard
`project.json` so the project gets the shared Nx targets automatically (a
`format` target for every project, plus a coverage-enabled `test` target for
test projects):

```bash
# Application workspace
scripts/new-dotnet-project.sh classlib -o libs/my-lib -n MyLib            # internal library
scripts/new-dotnet-project.sh webapi   -o apps/my-api -n MyApi            # application
scripts/new-dotnet-project.sh xunit    -o libs/my-lib-tests -n MyLib.Tests  # test project

# Publishable NuGet library workspace
scripts/new-dotnet-project.sh classlib -o packages/my-package -n MyPackage              # publishable package
scripts/new-dotnet-project.sh xunit    -o packages/my-package-tests -n MyPackage.Tests  # test project
scripts/new-dotnet-project.sh console  -o examples/my-package-sample -n MyPackage.Sample  # sample app
```

Test projects are detected from the template (`xunit`/`nunit`/`mstest`) or an
output directory ending in `-tests`. Force the choice with the `TEST_PROJECT`
env var (`TEST_PROJECT=1` / `TEST_PROJECT=0`). Any extra arguments are passed
straight through to `dotnet new`.

Common defaults (`TargetFramework`, `Nullable`, `ImplicitUsings`, central output
to `dist/`) are configured in the root `Directory.Build.props` and inherited by
every project.

Because the plugin builds with `--no-restore`, run `pnpm restore` (or
`dotnet restore`) once after creating or pulling new .NET projects:

```bash
pnpm restore
nx build my-api
nx test my-lib-tests
```

> **Note:** The template ships with a minimal sample .NET project
> (`libs/sample-lib` and `libs/sample-lib-tests`). The `@nx/dotnet` plugin
> requires at least one `.csproj`/`.fsproj` to be present in the workspace, so
> this sample keeps the workspace valid out of the box. Replace or delete it
> once you have added your own .NET projects.

## Packing & publishing NuGet packages

When using the publishable-library layout, the `@nx/dotnet` plugin provides a
`pack` target for every library, which builds a `.nupkg` into the central
`dist/` output:

```bash
# Pack a single package
nx pack my-package

# Pack every package in the workspace
nx run-many -t pack
```

Push the resulting `.nupkg` to your feed with `dotnet nuget push`, or wire it
into the semantic-release pipeline for automated publishing. Set package
metadata (`PackageId`, `Authors`, `Description`, `RepositoryUrl`, …) either per
project in the `.csproj` or centrally in the root `Directory.Build.props`.

## AI assistant support

This template ships with a vendor-neutral [`AGENTS.md`](./AGENTS.md) instead of
settings for any specific tool. It follows the [AGENTS.md](https://agents.md)
convention and is read automatically by several assistants (OpenCode, Cursor,
Aider, Gemini CLI, and others), telling them — among other things — to scaffold
new .NET projects with `scripts/new-dotnet-project.sh` so every project gets the
shared Nx targets.

Assistants that look for their own instruction file can reuse `AGENTS.md`
without committing tool-specific config to the repo:

- **Claude Code** reads `CLAUDE.md` — add one containing `@AGENTS.md` (or a
  symlink) locally if you use it.
- **GitHub Copilot** reads `.github/copilot-instructions.md` — point it at
  `AGENTS.md` the same way.

### Generating richer configuration with Nx

Nx can additionally configure your repository for AI coding assistants. It sets
up the Nx MCP server, shared skills and an `AGENTS.md` (or assistant-specific
instruction file) so the assistant understands the workspace.

```bash
# Interactively pick the assistants to configure
pnpm exec nx configure-ai-agents

# Or configure specific ones non-interactively
pnpm exec nx configure-ai-agents --agents claude codex copilot --no-interactive

# Check whether existing configurations are up to date
pnpm exec nx configure-ai-agents --check
```

Supported agents include `claude`, `codex`, `copilot`, `cursor`, `gemini` and
`opencode`. Re-run the command after upgrading Nx to keep the generated
configuration current.

## References

- [pnpm](https://pnpm.io/)
- [pnpm Workspaces](https://pnpm.io/workspaces)
- [Nx](https://nx.dev/)
- [@nx/dotnet](https://nx.dev/docs/technologies/dotnet/introduction)
- [Nx AI integration](https://nx.dev/features/enhance-AI)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [semantic-release](https://semantic-release.gitbook.io/semantic-release)
- [Arc42](https://arc42.org/)
- [Astro](https://astro.build/)
- [Astro Starlight](https://starlight.astro.build/)
- [nx-monorepo](https://github.com/froko/nx-monorepo)
