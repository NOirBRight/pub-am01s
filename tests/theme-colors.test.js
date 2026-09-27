import { describe, expect, it } from 'vitest'
import { parseTheme } from '../plugin/theme-colors.mjs'

describe('parseTheme', () => {
  it('reads orange, then color3, then yellow', () => {
    expect(parseTheme('orange = "#a2734b"\ncolor3 = "#112233"\n').orange).toBe('#a2734b')
    expect(parseTheme('color3 = "#112233"\nyellow = "#445566"\n').orange).toBe('#112233')
    expect(parseTheme("yellow = '#445566'\n").orange).toBe('#445566')
    expect(parseTheme('foreground = "#C1C497"\n').orange).toBe('')
  })

  it('keeps the inbox roles on one object', () => {
    const theme = parseTheme([
      'lighter_background = "#22332c"',
      'selection_background = "#33443c"',
      'bright_foreground = "#f4f1e4"',
      'dark_foreground = "#8a8668"',
      'dark_background = "#0c1411"',
    ].join('\n'))
    expect(theme).toMatchObject({
      bgLight: '#22332c',
      sel: '#33443c',
      fgBright: '#f4f1e4',
      fgDim: '#8a8668',
      bgDark: '#0c1411',
    })
  })
})
