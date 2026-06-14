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

By default, the pnpm workspace comes with preconfigured directories for `apps`
and `libs`. You can add more directories or change the default ones by modifying
the `pnpm-workspace.yaml` file. Nx will automatically adhere to these changes.

## Adding .NET projects

.NET projects are created with the standard `dotnet new` CLI. The `@nx/dotnet`
plugin automatically detects any `.csproj`, `.fsproj` or `.vbproj` file and adds
the corresponding Nx targets (`build`, `test`, `restore`, `clean`, `publish`,
`pack`, `run`, `watch`).

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

## Adding AI assistant support

Nx can configure your repository for AI coding assistants. It sets up the Nx MCP
server, shared skills and an `AGENTS.md` (or assistant-specific instruction
file) so the assistant understands the workspace.

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
