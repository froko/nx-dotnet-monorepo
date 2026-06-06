// @ts-check
import { defineConfig } from 'astro/config'
import starlight from '@astrojs/starlight'
import remarkPlantuml from './src/plugins/remark-plantuml.mjs'

// https://astro.build/config
export default defineConfig({
  // Keep outDir inside the project root. Astro stages image originals in a
  // fallback `.astro/` dir when outDir is outside cwd, which breaks image
  // optimization on a clean cache (e.g. in CI).
  outDir: './dist',
  markdown: {
    remarkPlugins: [remarkPlantuml],
  },
  image: {
    service: {
      entrypoint: 'astro/assets/services/sharp',
    },
  },
  integrations: [
    starlight({
      title: 'nx-dotnet-monorepo',
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          href: 'https://github.com/froko/nx-dotnet-monorepo',
        },
      ],
      sidebar: [
        {
          label: 'Architecture',
          items: [
            {
              label: 'Introduction and Goals',
              link: '/arc42/introduction-and-goals',
            },
            {
              label: 'Architecture Constraints',
              link: '/arc42/architecture-constraints',
            },
            {
              label: 'System Scope and Context',
              link: '/arc42/system-scope-and-context',
            },
            { label: 'Solution Strategy', link: '/arc42/solution-strategy' },
            {
              label: 'Building Block View',
              link: '/arc42/building-block-view',
            },
            { label: 'Runtime View', link: '/arc42/runtime-view' },
            { label: 'Deployment View', link: '/arc42/deployment-view' },
            {
              label: 'Cross-cutting Concepts',
              link: '/arc42/cross-cutting-concepts',
            },
            {
              label: 'Architecture Decisions',
              link: '/arc42/architecture-decisions',
            },
            {
              label: 'Quality Requirements',
              link: '/arc42/quality-requirements',
            },
            {
              label: 'Risks and Technical Depts',
              link: '/arc42/risks-and-technical-depts',
            },
            { label: 'Glossary', link: '/arc42/glossary' },
          ],
        },
        {
          label: 'Concepts',
          items: [{ autogenerate: { directory: 'concepts' } }],
        },
        {
          label: 'Guides',
          items: [{ autogenerate: { directory: 'guides' } }],
        },
        {
          label: 'References',
          items: [{ autogenerate: { directory: 'references' } }],
        },
      ],
    }),
  ],
})
