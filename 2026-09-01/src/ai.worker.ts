/// <reference lib="webworker" />

import { CreateMLCEngine, type MLCEngine } from '@mlc-ai/web-llm'
import { expandAiReport, type ReportInput } from './generator'

const MODEL_ID = 'Qwen2.5-0.5B-Instruct-q4f16_1-MLC'
let engine: MLCEngine | null = null

const stateLabels: Record<ReportInput['state'], string> = {
  'not-started': 'まだ着手していない',
  working: '作業中',
  blocked: '詰まっている',
  waiting: '相手の返事を待っている',
  'almost-done': 'ほぼ終わっている',
  unknown: '自分でも状況が分からない',
}

const toneLabels: Record<ReportInput['tone'], string> = {
  safe: '無難',
  consulting: 'コンサル風',
  executive: '役員報告風',
  buzzword: '横文字を少し使う',
  honest: '正直',
}

const worker = self as DedicatedWorkerGlobalScope

const systemPrompt = `あなたは日本企業の進捗報告を作る編集者です。入力された事実だけを使い、報告の核になる文章を作ります。
対象名を必ずそのまま含め、40〜100文字程度、1〜2文で出力してください。
「実情:」の後ろにある語句を、省略も言い換えもせず、そのまま引用符なしで文章中に含めて現在地を述べます。必要なら確認・整理・検討している観点を加えます。
新しい事実、作業、成果、完了、期限、人物、数値、英単語を追加してはいけません。入力された実情より進んでいると見せる断定も禁止です。
文体と曖昧さの指定を文章全体へ反映し、曖昧さが高いほど抽象度を上げます。
前置き、引用符、Markdown、見出し、箇条書き、解説は付けず、報告本文だけを出力してください。`

const stateExamples: Record<ReportInput['state'], { input: string; output: string }> = {
  'not-started': {
    input: '対象: 設定画面\n実情: まだ着手していない\n文体: 無難\n曖昧さ: 50/100',
    output: '設定画面については、まだ着手していない状態であり、具体的な作業へ移る前の段階です。',
  },
  working: {
    input: '対象: 取込機能\n実情: 作業中\n文体: 無難\n曖昧さ: 50/100',
    output: '取込機能については現在作業中であり、内容と影響範囲を確認しています。',
  },
  blocked: {
    input: '対象: 通知機能\n実情: 詰まっている\n文体: 役員報告風\n曖昧さ: 50/100',
    output: '通知機能については現在詰まっている状態であり、前提と影響範囲を確認しています。',
  },
  waiting: {
    input: '対象: 集計資料\n実情: 相手の返事を待っている\n文体: コンサル風\n曖昧さ: 75/100',
    output: '集計資料については相手の返事を待っている状態であり、次の判断に向けた論点を整理しています。',
  },
  'almost-done': {
    input: '対象: 検索機能\n実情: ほぼ終わっている\n文体: 無難\n曖昧さ: 50/100',
    output: '検索機能については現在ほぼ終わっている状態であり、残っている確認事項を整理しています。',
  },
  unknown: {
    input: '対象: 管理画面\n実情: 自分でも状況が分からない\n文体: 正直\n曖昧さ: 25/100',
    output: '管理画面については自分でも状況が分からない状態であり、全体像を把握するための確認をしています。',
  },
}

async function createReport(input: ReportInput, retry = false) {
  if (!engine) throw new Error('AIモデルが準備できていません')
  const { subject, state, tone, ambiguity } = input
  const example = stateExamples[state]
  const retryInstruction = retry
    ? `\n追加条件: 前回の出力は形式または実情との一致を満たしませんでした。「${stateLabels[state]}」を一字も変えずに文章中へ含め、対象名を含む1〜2文に書き直してください。`
    : ''
  const response = await engine.chat.completions.create({
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: example.input },
      { role: 'assistant', content: example.output },
      {
        role: 'user',
        content: `対象: ${subject}\n実情: ${stateLabels[state]}\n文体: ${toneLabels[tone]}\n曖昧さ: ${ambiguity}/100${retryInstruction}`,
      },
    ],
    temperature: retry ? 0.55 : 0.72,
    top_p: 0.9,
    max_tokens: 160,
  })
  return response.choices[0]?.message.content ?? ''
}

worker.onmessage = async (event: MessageEvent<{ type: 'load' } | { type: 'generate'; input: ReportInput }>) => {
  try {
    if (event.data.type === 'load') {
      engine = await CreateMLCEngine(MODEL_ID, {
        initProgressCallback: ({ progress, text }) => {
          worker.postMessage({ type: 'progress', progress, text })
        },
      })
      worker.postMessage({ type: 'ready' })
      return
    }

    let core = await createReport(event.data.input)
    let report = expandAiReport(core, event.data.input)
    if (!report) {
      core = await createReport(event.data.input, true)
      report = expandAiReport(core, event.data.input)
    }
    worker.postMessage({ type: 'result', report: report ?? core })
  } catch (error) {
    worker.postMessage({
      type: 'error',
      message: error instanceof Error ? error.message : 'ローカルAIで問題が発生しました',
    })
  }
}
