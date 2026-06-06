import plantumlEncoder from 'plantuml-encoder'
import { visit } from 'unist-util-visit'

const DEFAULT_OPTIONS = {
  baseUrl: 'https://www.plantuml.com/plantuml/png',
}

/**
 * Remark plugin that turns ```plantuml fenced code blocks into images rendered
 * by a PlantUML server.
 *
 * This is a local, maintained replacement for `@akebifiky/remark-simple-plantuml`,
 * which depended on an outdated `unist-util-visit@2` and broke the docs build.
 *
 * @param {{ baseUrl?: string }} [pluginOptions]
 */
export default function remarkPlantuml(pluginOptions) {
  const options = { ...DEFAULT_OPTIONS, ...pluginOptions }

  return function transformer(tree) {
    visit(tree, 'code', (node) => {
      const { lang, value, meta } = node

      if (!lang || !value || lang !== 'plantuml') return

      node.type = 'image'
      node.url = `${options.baseUrl.replace(/\/$/, '')}/${plantumlEncoder.encode(value)}`
      node.alt = meta
      node.meta = undefined
    })

    return tree
  }
}
