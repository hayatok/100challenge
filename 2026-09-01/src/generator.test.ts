import { describe, expect, it } from 'vitest'
import { expandAiReport, generateReport, sanitizeSubject, validateAiReport } from './generator'

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
    const report =
      'ログイン画面については、現在の状況を踏まえ、進め方を判断するための前提条件と影響範囲を整理しています。足元では、認識のずれを避ける観点から確認すべき論点の粒度を揃え、優先順位を見極められる状態へ近づけています。今後も、確定していない内容を断定せず、確認できた範囲をもとに慎重に検討を進めます。'
    expect(validateAiReport(report, 'ログイン画面')).toBe(report)
  })

  it('事実を断定する出力を拒否する', () => {
    expect(validateAiReport('ログイン画面をリリースしました。', 'ログイン画面')).toBeNull()
  })

  it('入力にない数値と英単語を拒否する', () => {
    expect(validateAiReport('ログイン画面を30日以内に対応する Summary。', 'ログイン画面')).toBeNull()
  })

  it('短すぎる出力と1文だけの出力を拒否する', () => {
    expect(validateAiReport('ログイン画面について、影響範囲を確認しています。', 'ログイン画面')).toBeNull()
    expect(
      validateAiReport(
        `ログイン画面について、${'前提と影響範囲を慎重に整理しながら'.repeat(8)}確認しています。`,
        'ログイン画面',
      ),
    ).toBeNull()
  })

  it('長すぎる出力と5文以上の出力を拒否する', () => {
    expect(
      validateAiReport(
        `ログイン画面について整理しています。${'影響範囲を慎重に確認しています。'.repeat(20)}`,
        'ログイン画面',
      ),
    ).toBeNull()
    expect(
      validateAiReport(
        `ログイン画面について整理しています。${'あ'.repeat(30)}。${'い'.repeat(30)}。${'う'.repeat(30)}。${'え'.repeat(30)}。`,
        'ログイン画面',
      ),
    ).toBeNull()
  })
})

describe('expandAiReport', () => {
  it('安全なAIの短文を状態と文体に応じた長文へ拡張する', () => {
    const core = 'ログイン画面については、まだ着手していない状態であり、現状を確認している段階です。'
    const report = expandAiReport(core, { ...baseInput, tone: 'consulting', ambiguity: 75 })
    expect(report).toBeTruthy()
    expect(report).toContain(core)
    expect(report!.length).toBeGreaterThanOrEqual(120)
    expect((report!.match(/。/g) ?? []).length).toBe(3)
  })

  it('危険な事実を含むAIの短文は拡張しない', () => {
    expect(
      expandAiReport('ログイン画面については、対応済であり、現在は確認している段階です。', baseInput),
    ).toBeNull()
  })

  it('入力した状態と一致しないAIの短文は拡張しない', () => {
    expect(
      expandAiReport(
        'ログイン画面については、必要最小限の作業を進める方向に変更しています。',
        { ...baseInput, state: 'blocked' },
      ),
    ).toBeNull()
  })

  it.each([
    ['working', 'ログイン画面については現在作業中であり、内容を確認しています。'],
    ['blocked', 'ログイン画面については現在詰まっている状態であり、前提を確認しています。'],
    ['waiting', 'ログイン画面については相手の返事を待っている状態であり、論点を整理しています。'],
    ['almost-done', 'ログイン画面については現在ほぼ終わっている状態であり、残りを確認しています。'],
    ['unknown', 'ログイン画面については自分でも状況が分からない状態であり、現在地を確認しています。'],
  ] as const)('%sの安全な核を長文へ拡張する', (state, core) => {
    const report = expandAiReport(core, { ...baseInput, state })
    expect(report).toBeTruthy()
    expect(report!.length).toBeGreaterThanOrEqual(120)
    expect(report!.length).toBeLessThanOrEqual(300)
    expect(validateAiReport(report!, 'ログイン画面')).toBe(report)
  })
})
