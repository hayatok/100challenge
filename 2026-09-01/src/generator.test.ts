import { describe, expect, it } from 'vitest'
import { generateReport, sanitizeSubject, validateAiReport } from './generator'

const baseInput = {
  subject: 'ログイン画面',
  state: 'not-started' as const,
  tone: 'safe' as const,
  ambiguity: 50,
}

describe('generateReport', () => {
  it('対象を含む一文を生成する', () => {
    const report = generateReport(baseInput, [], () => 0)
    expect(report).toContain('ログイン画面')
    expect(report.endsWith('。')).toBe(true)
    expect(report).not.toMatch(/にを|ながらを/)
  })

  it('空の対象を拒否する', () => {
    expect(() => generateReport({ ...baseInput, subject: '  ' })).toThrow('対象を入力してください')
  })

  it('対象の改行と長さを正規化する', () => {
    expect(sanitizeSubject(`  料金\nプラン ${'あ'.repeat(80)}`)).toHaveLength(60)
  })
})

describe('validateAiReport', () => {
  it('対象を含む安全な出力を受け入れる', () => {
    expect(validateAiReport('ログイン画面について、影響範囲を確認しています。', 'ログイン画面')).toBeTruthy()
  })

  it('事実を断定する出力を拒否する', () => {
    expect(validateAiReport('ログイン画面をリリースしました。', 'ログイン画面')).toBeNull()
  })

  it('入力にない数値と英単語を拒否する', () => {
    expect(validateAiReport('ログイン画面を30日以内に対応する Summary。', 'ログイン画面')).toBeNull()
  })
})
