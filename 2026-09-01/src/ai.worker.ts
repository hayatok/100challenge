/// <reference lib="webworker" />

import { CreateMLCEngine, type MLCEngine } from '@mlc-ai/web-llm'
import type { ReportInput } from './generator'

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

    if (!engine) throw new Error('AIモデルが準備できていません')

    const { subject, state, tone, ambiguity } = event.data.input
    const response = await engine.chat.completions.create({
      messages: [
        {
          role: 'system',
          content:
            'あなたは日本企業の進捗報告を作る編集者です。入力された対象名を必ずそのまま含め、自然な日本語を1文だけ出力します。新しい事実、作業、完了、期限、人物、数値、英単語を追加してはいけません。断定を避け、整理、確認、検討、調整という表現を使います。前置き、引用符、Markdown、見出し、解説は禁止です。100文字以内にしてください。',
        },
        {
          role: 'user',
          content: '対象: ログイン画面\n実情: まだ着手していない\n文体: 無難\n曖昧さ: 50/100',
        },
        {
          role: 'assistant',
          content: 'ログイン画面については、着手に向けた前提条件の整理と影響範囲の確認を進めています。',
        },
        {
          role: 'user',
          content: '対象: 月次レポート\n実情: 相手の返事を待っている\n文体: コンサル風\n曖昧さ: 75/100',
        },
        {
          role: 'assistant',
          content: '月次レポートについては、関係者との認識を揃えつつ、次の判断に必要な論点を整理しています。',
        },
        {
          role: 'user',
          content: `対象: ${subject}\n実情: ${stateLabels[state]}\n文体: ${toneLabels[tone]}\n曖昧さ: ${ambiguity}/100`,
        },
      ],
      temperature: 0.7,
      top_p: 0.9,
      max_tokens: 70,
    })

    worker.postMessage({ type: 'result', report: response.choices[0]?.message.content ?? '' })
  } catch (error) {
    worker.postMessage({
      type: 'error',
      message: error instanceof Error ? error.message : 'ローカルAIで問題が発生しました',
    })
  }
}
