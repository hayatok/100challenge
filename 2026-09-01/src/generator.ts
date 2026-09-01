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

export const AI_REPORT_MIN_LENGTH = 120
export const AI_REPORT_MAX_LENGTH = 300
const AI_CORE_MIN_LENGTH = 20
const AI_CORE_MAX_LENGTH = 120

const aiCoreStatePatterns: Record<ProgressState, RegExp> = {
  'not-started': /着手していない/,
  working: /作業中/,
  blocked: /詰まっている/,
  waiting: /返事を待っている/,
  'almost-done': /ほぼ終わっている/,
  unknown: /状況が分からない/,
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

const aiStateExpansions: Record<ProgressState, string> = {
  'not-started':
    'そのうえで、着手後の手戻りを抑える観点から、前提条件と影響範囲を確認し、何を先に整理すべきかという論点の粒度を揃えています。',
  working:
    'そのうえで、進行中の内容と周辺への影響を切り分け、認識のずれや抜け漏れが生じないよう、確認すべき観点を整理しています。',
  blocked:
    'そのうえで、顕在化している論点を切り分け、前提の置き方と影響範囲を確認しながら、次の判断に必要な材料を整理しています。',
  waiting:
    'そのうえで、返答を受けた後に認識のずれが生じないよう、確認すべき観点と進め方の選択肢をあらかじめ整理しています。',
  'almost-done':
    'そのうえで、残っている確認事項と周辺への影響を切り分け、見落としを避けるために必要な観点を慎重に整理しています。',
  unknown:
    'そのうえで、現在地を把握するために関係する情報を切り分け、優先順位を判断するうえで不足している観点を整理しています。',
}

const aiToneExpansions: Record<Tone, (ambiguity: number) => string> = {
  safe: (ambiguity) =>
    ambiguity >= 75
      ? '引き続き、確定していない内容を断定せず、複数の見方を残したまま、状況に応じて調整できる進め方を慎重に見極めます。'
      : '引き続き、確認できた範囲をもとに優先順位を見極め、状況に応じて調整できる進め方を検討します。',
  consulting: (ambiguity) =>
    ambiguity >= 75
      ? '引き続き、全体の整合性を崩さないよう複数の見方を保持しながら、判断に必要な論点の解像度を段階的に高めていきます。'
      : '引き続き、全体の整合性を確認しながら、次の判断に必要な論点の解像度を段階的に高めていきます。',
  executive: () =>
    '引き続き、判断に影響する要素を見極めながら、優先順位とリスクを管理できる状態へ近づけていきます。',
  buzzword: () =>
    '引き続き、全体の方向性と認識を揃えながら、次の動きへ移るための論点と進め方を段階的に具体化していきます。',
  honest: () =>
    '引き続き、進んでいない点を無理に飾らず、確認できたことと分からないことを分けながら次の進め方を考えます。',
}

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
  if (normalized.length < AI_REPORT_MIN_LENGTH || normalized.length > AI_REPORT_MAX_LENGTH) return null
  if (!normalized.includes(normalizedSubject)) return null
  if (/完了|リリース|合意|承認|実施済|対応済/.test(normalized)) return null
  const sentenceCount = (normalized.match(/[。！？]/g) ?? []).length
  if (sentenceCount < 3 || sentenceCount > 4 || !/[。！？]$/.test(normalized)) return null

  const subjectNumbers = new Set(normalizedSubject.match(/\d+(?:[./-]\d+)*/g) ?? [])
  const reportNumbers = normalized.match(/\d+(?:[./-]\d+)*/g) ?? []
  if (reportNumbers.some((value) => !subjectNumbers.has(value))) return null

  const subjectWords = new Set(normalizedSubject.match(/[A-Za-z][A-Za-z0-9/-]*/g) ?? [])
  const reportWords = normalized.match(/[A-Za-z][A-Za-z0-9/-]*/g) ?? []
  if (reportWords.some((value) => !subjectWords.has(value))) return null
  return normalized
}

function validateAiCore(report: string, input: ReportInput) {
  const normalized = report.trim().replace(/^['"「]|['"」]$/g, '')
  const normalizedSubject = sanitizeSubject(input.subject)
  if (normalized.length < AI_CORE_MIN_LENGTH || normalized.length > AI_CORE_MAX_LENGTH) return null
  if (!normalized.includes(normalizedSubject)) return null
  if (/完了|リリース|合意|承認|実施済|対応済|変更して|着手しました|開始しました|作成しました|提出しました|共有しました/.test(normalized)) return null
  if (!aiCoreStatePatterns[input.state].test(normalized)) return null
  const sentenceCount = (normalized.match(/[。！？]/g) ?? []).length
  if (sentenceCount < 1 || sentenceCount > 2 || !/[。！？]$/.test(normalized)) return null

  const subjectNumbers = new Set(normalizedSubject.match(/\d+(?:[./-]\d+)*/g) ?? [])
  const reportNumbers = normalized.match(/\d+(?:[./-]\d+)*/g) ?? []
  if (reportNumbers.some((value) => !subjectNumbers.has(value))) return null

  const subjectWords = new Set(normalizedSubject.match(/[A-Za-z][A-Za-z0-9/-]*/g) ?? [])
  const reportWords = normalized.match(/[A-Za-z][A-Za-z0-9/-]*/g) ?? []
  if (reportWords.some((value) => !subjectWords.has(value))) return null
  return normalized
}

export function expandAiReport(report: string, input: ReportInput) {
  const core = validateAiCore(report, input)
  if (!core) return null
  const expanded = `${core}${aiStateExpansions[input.state]}${aiToneExpansions[input.tone](input.ambiguity)}`
  return validateAiReport(expanded, input.subject)
}
