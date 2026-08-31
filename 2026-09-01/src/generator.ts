export const progressStates = [
  { value: 'not-started', label: '未着手', hint: 'まずは気持ちから' },
  { value: 'working', label: '作業中', hint: 'いちばん安全' },
  { value: 'blocked', label: '詰まった', hint: '論点が豊作' },
  { value: 'waiting', label: '返事待ち', hint: 'ボールは先方' },
  { value: 'almost-done', label: 'ほぼ完了', hint: 'ほぼ、です' },
  { value: 'unknown', label: '不明', hint: '観測から開始' },
] as const

export const tones = [
  { value: 'safe', label: '無難' },
  { value: 'consulting', label: 'コンサル風' },
  { value: 'executive', label: '役員報告風' },
  { value: 'buzzword', label: '横文字過多' },
  { value: 'honest', label: '正直風' },
] as const

export type ProgressState = (typeof progressStates)[number]['value']
export type Tone = (typeof tones)[number]['value']

export type ReportInput = {
  subject: string
  state: ProgressState
  tone: Tone
  ambiguity: number
}

type RandomSource = () => number

const statePhrases: Record<ProgressState, string[]> = {
  'not-started': [
    '着手に向けた前提条件の整理',
    'スムーズな立ち上がりに必要な論点の洗い出し',
    '初動での手戻りを防ぐための準備',
    '進め方を具体化するための情報収集',
  ],
  working: [
    '主要部分の検証と細部の調整',
    '実装方針に沿った作業と影響範囲の確認',
    '優先度の高い箇所から順次対応',
    '品質を担保するための確認作業',
  ],
  blocked: [
    '顕在化した論点の切り分けと解消方法の検討',
    '進行を阻む要因の特定と対応方針の整理',
    '複数の選択肢を比較したうえでの打開策の検討',
    '前提の再確認とクリティカルな論点の精査',
  ],
  waiting: [
    '関係者との認識合わせと回答後の進め方の整理',
    '確認事項の共有と次工程に向けた準備',
    '必要なフィードバックの回収と周辺作業の先行対応',
    'ステークホルダーとの合意形成に向けた調整',
  ],
  'almost-done': [
    '最終確認と残論点の解消',
    '仕上げに向けた品質確認と微調整',
    '反映前のチェックと周辺への影響確認',
    '抜け漏れを防ぐための最終的な精査',
  ],
  unknown: [
    '現状の可視化と優先順位の整理',
    '関係情報の収集と全体像の把握',
    '現在地を明確にするための状況確認',
    '次の一手を定めるための論点整理',
  ],
}

const toneOpeners: Record<Tone, string[]> = {
  safe: ['現在', '現時点では', '足元では', 'まずは'],
  consulting: ['解像度を高めながら', '論点の粒度を揃えつつ', '全体最適の観点から', '仮説を置きながら'],
  executive: ['優先順位を見極めながら', 'リスクを注視しつつ', '事業影響を踏まえ', '意思決定に必要な材料を揃えながら'],
  buzzword: ['スコープを再アラインしつつ', 'ステークホルダーと目線をアラインしながら', 'ボトルネックをケアしつつ', 'アウトカムを意識しながら'],
  honest: ['正直なところ', '少なくとも今は', '大きくは進んでいませんが', '見栄を張らずに言うと'],
}

const toneClosers: Record<Tone, string[]> = {
  safe: ['進めています', '取り組んでいます', '順次進めています'],
  consulting: ['進め、次のアクションを具体化しています', '進行上の不確実性を下げています', '進めながら、打ち手の精度を高めています'],
  executive: ['進め、判断可能な状態へ近づけています', 'リスクを管理可能な範囲へ収めています', '優先し、次の意思決定に備えています'],
  buzzword: ['ドライブし、ネクストアクションへコミットしています', 'ハンドリングしながら、アウトプットをブラッシュアップしています', '推進し、デリバリーに向けたバリューを最大化しています'],
  honest: ['確認している段階です', '着手しています', '進めています'],
}

const vagueBridges = [
  '周辺領域への影響も確認しながら',
  '認識のずれが生じないよう留意しつつ',
  '関係各所との連携可能性も視野に入れながら',
  '今後の展開も踏まえて慎重に',
]

const templates = [
  (subject: string, opener: string, phrase: string, bridge: string, closer: string) =>
    `${subject}については、${opener}、${phrase}${bridge}${closer}。`,
  (subject: string, opener: string, phrase: string, bridge: string, closer: string) =>
    `${subject}は、${opener}、${phrase}${bridge}${closer}。`,
  (subject: string, opener: string, phrase: string, bridge: string, closer: string) =>
    `${subject}に関して、${opener}、${phrase}${bridge}${closer}。`,
]

const pick = <T,>(items: readonly T[], random: RandomSource) =>
  items[Math.min(items.length - 1, Math.floor(random() * items.length))]

export function sanitizeSubject(subject: string) {
  return subject.trim().replace(/[\r\n\t]+/g, ' ').replace(/\s{2,}/g, ' ').slice(0, 60)
}

export function generateReport(
  input: ReportInput,
  recent: readonly string[] = [],
  random: RandomSource = Math.random,
) {
  const subject = sanitizeSubject(input.subject)
  if (!subject) throw new Error('対象を入力してください')

  let report = ''
  for (let attempt = 0; attempt < 12; attempt += 1) {
    const opener = pick(toneOpeners[input.tone], random)
    const phrase = pick(statePhrases[input.state], random)
    const closer = pick(toneClosers[input.tone], random)
    const bridge = input.ambiguity >= 75 ? `を軸に、${pick(vagueBridges, random)}` : 'を中心に'
    report = pick(templates, random)(subject, opener, phrase, bridge, closer)
    if (!recent.includes(report)) break
  }
  return report
}

export function validateAiReport(report: string, subject: string) {
  const normalized = report.trim().replace(/^['"「]|['"」]$/g, '')
  const normalizedSubject = sanitizeSubject(subject)
  if (!normalized || normalized.length > 120) return null
  if (!normalized.includes(normalizedSubject)) return null
  if (/完了|リリース|合意|承認|実施済|対応済/.test(normalized)) return null
  if ((normalized.match(/[。！？]/g) ?? []).length > 1) return null

  const subjectNumbers = new Set(normalizedSubject.match(/\d+(?:[./-]\d+)*/g) ?? [])
  const reportNumbers = normalized.match(/\d+(?:[./-]\d+)*/g) ?? []
  if (reportNumbers.some((value) => !subjectNumbers.has(value))) return null

  const subjectWords = new Set(normalizedSubject.match(/[A-Za-z][A-Za-z0-9/-]*/g) ?? [])
  const reportWords = normalized.match(/[A-Za-z][A-Za-z0-9/-]*/g) ?? []
  if (reportWords.some((value) => !subjectWords.has(value))) return null
  return normalized
}
