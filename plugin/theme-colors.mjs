// One parse of the Omarchy colors.toml. Panel, meters, and inbox share it.

export function parseTheme(raw) {
  const found = {}
  const lines = String(raw || '').split('\n')
  for (let i = 0; i < lines.length; i += 1) {
    const match = lines[i].match(/^\s*([A-Za-z0-9_]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
    if (match) found[match[1]] = match[2]
  }
  return {
    orange: found.orange || found.color3 || found.yellow || '',
    bgLight: found.lighter_background || '',
    sel: found.selection || found.selection_background || '',
    fgBright: found.bright_foreground || found.light_foreground || '',
    fgDim: found.dark_foreground || '',
    bgDark: found.dark_background || '',
  }
}
