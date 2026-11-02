import { Marked } from 'marked';

export const MAX_LENGTH = 100000;
const escapeHtml = value => value.replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]);
const parser = new Marked({ gfm: true, breaks: false, renderer: {
  html: ({ text }) => escapeHtml(text),
  image: ({ text }) => `<span class="image-placeholder">画像: ${escapeHtml(text || '代替テキストなし')}</span>`,
} });

export const LESSONS = [
  { id: 'heading', label: '見出し', symbol: 'H₂', summary: '文書を章に分ける', syntax: '## 準備', explanation: '行の先頭に半角の # とスペースを置きます。# は大見出し、## はその下の見出しです。', prompt: '「準備」をレベル2の見出しにしてください。', answer: '## 準備', hint: '行の先頭に ## と半角スペースを置き、その後に「準備」と書きます。', extension: false },
  { id: 'bold', label: '太字', symbol: 'B', summary: '大切な言葉を目立たせる', syntax: '**必須**', explanation: '強調したい言葉の前後を、半角のアスタリスク2つで囲みます。記号のすぐ内側にスペースは入れません。', prompt: '「これは必須です。」の「必須」だけを太字にしてください。', answer: 'これは**必須**です。', hint: '「必須」の前と後だけに ** を付けます。文の残りは囲みません。', extension: false },
  { id: 'list', label: '箇条書き', symbol: '≡', summary: '項目を並べる', syntax: '- ノート\n- ペン', explanation: '各行の先頭に半角の - とスペースを置きます。順番がある手順は、1. とスペースから始める番号付きリストも使えます。', prompt: '「ノート」「ペン」の順で、2項目の箇条書きを作ってください。', answer: '- ノート\n- ペン', hint: '2行に分け、各行を - と半角スペースで始めます。番号は付けません。', extension: false },
  { id: 'link', label: 'リンク', symbol: '↗', summary: '参考資料へ案内する', syntax: '[参考資料](https://example.com)', explanation: '表示する名前を [ ]、リンク先のURLを ( ) で囲み、続けて書きます。', prompt: 'https://example.com へ移動する「参考資料」というリンクを作ってください。', answer: '[参考資料](https://example.com)', hint: '名前を [参考資料]、URLを (https://example.com) と書き、間を空けずにつなぎます。', extension: false },
  { id: 'quote', label: '引用', symbol: '❞', summary: '引用した言葉を区別する', syntax: '> 急がば回れ。', explanation: '引用する行の先頭に半角の > とスペースを置きます。出典も本文に添えると、誰の言葉か伝わります。', prompt: '「急がば回れ。」を引用にしてください。', answer: '> 急がば回れ。', hint: '行の先頭に > と半角スペースを置きます。', extension: false },
  { id: 'code', label: 'コード', symbol: '</>', summary: 'コマンドをそのまま示す', syntax: '```sh\nnpm install\n```', explanation: '半角のバッククォート3つを上下に置いて囲みます。中の記号はMarkdownの書式に変換されません。短いコードは ` と ` で囲めます。', prompt: 'npm install を、上下のフェンスを閉じたコードブロックにしてください。', answer: '```sh\nnpm install\n```', hint: '最初と最後の行に ``` を置き、間の行に npm install と書きます。', extension: false },
  { id: 'task', label: 'タスク', symbol: '☑', summary: '作業の完了を記録する', syntax: '- [ ] 下書き\n- [x] 確認', explanation: '- の後に [ ] を置くと未完了、[x] を置くと完了です。プレビューのチェックは表示用です。状態はMarkdownの本文で変えます。', prompt: '未完了の「下書き」と、完了した「確認」をこの順で作ってください。', answer: '- [ ] 下書き\n- [x] 確認', hint: '未完了は - [ ] 下書き、完了は - [x] 確認 と2行で書きます。', extension: true },
  { id: 'table', label: '表', symbol: '▦', summary: '情報を列で比べる', syntax: '| 項目 | 内容 |\n| --- | --- |\n| 日時 | 10時 |', explanation: '列を半角の | で区切り、見出しの次に --- の区切り行を置きます。表とタスクはGFMの拡張で、表示先によって対応が異なります。', prompt: '見出しが「項目」「内容」、データが「日時」「10時」の2列の表を作ってください。', answer: '| 項目 | 内容 |\n| --- | --- |\n| 日時 | 10時 |', hint: '見出し行とデータ行の間に | --- | --- | の区切り行が必要です。', extension: true },
];
export const TEMPLATES = {
  memo: { title: 'はじめてのメモ', content: '# はじめてのメモ\n\n思いついたことを、ここに書いてみましょう。\n\n## 今日やること\n\n- 調べたいことをメモする\n- **大切なこと**を目立たせる\n\n## 気づいたこと\n\n書式ボタンを押すと、記法と書き方を確かめられます。\n' },
  procedure: { title: '作業の手順書', content: '# 作業の手順書\n\n## 目的\n\n何のための作業かを書きます。\n\n## 用意するもの\n\n- 必要なもの\n\n## 手順\n\n1. 最初の作業\n2. 次の作業\n3. 結果を確認する\n\n## 確認すること\n\n- [ ] 作業が完了した\n- [ ] 結果を確認した\n\n## 補足\n\n注意点や参考資料を添えます。\n' },
  blank: { title: '無題のメモ', content: '' },
};

export function parseMarkdown(text) {
  const tokens = parser.lexer(text);
  const used = new Set();
  parser.walkTokens(tokens, token => {
    const id = { heading: 'heading', strong: 'bold', link: 'link', blockquote: 'quote', code: 'code', codespan: 'code', table: 'table' }[token.type];
    if (id) used.add(id);
    if (token.type === 'list') {
      if (token.items.some(item => item.task)) used.add('task');
      if (token.items.some(item => !item.task)) used.add('list');
    }
  });
  return { html: parser.parser(tokens), used };
}
const meaningful = tokens => tokens.filter(token => token.type !== 'space');
const plain = token => token.tokens ? token.tokens.map(plain).join('') : token.text || '';

export function checkExercise(id, answer) {
  const lesson = LESSONS.find(item => item.id === id);
  if (!lesson || typeof answer !== 'string' || answer.length > MAX_LENGTH) return { ok: false, message: '回答を確認できません。練習を選び直してください。' };
  const tokens = meaningful(parser.lexer(answer));
  const first = tokens[0];
  let ok = false;
  if (tokens.length === 1) {
    if (id === 'heading') ok = first.type === 'heading' && first.depth === 2 && plain(first) === '準備';
    if (id === 'bold' && first.type === 'paragraph') {
      const strong = first.tokens.filter(token => token.type === 'strong');
      ok = plain(first).replace(/\s/g, '') === 'これは必須です。' && strong.length === 1 && plain(strong[0]) === '必須';
    }
    if (id === 'list') ok = first.type === 'list' && !first.ordered && first.items.length === 2 && first.items.every((item, index) => !item.task && plain(item) === ['ノート', 'ペン'][index]);
    if (id === 'link' && first.type === 'paragraph') ok = first.tokens.length === 1 && first.tokens[0].type === 'link' && first.tokens[0].href === 'https://example.com' && plain(first.tokens[0]) === '参考資料';
    if (id === 'quote') ok = first.type === 'blockquote' && meaningful(first.tokens).length === 1 && first.tokens[0].type === 'paragraph' && plain(first.tokens[0]) === '急がば回れ。';
    if (id === 'code') {
      const lines = answer.split(/\r?\n/);
      while (lines.length && !lines[0].trim()) lines.shift();
      while (lines.length && !lines.at(-1).trim()) lines.pop();
      const opening = lines[0]?.match(/^ {0,3}(`{3,}|~{3,})[^\n]*$/);
      const closing = lines.at(-1)?.replace(/[ \t]+$/, '');
      ok = first.type === 'code' && first.text === 'npm install' && !!opening && lines.length >= 3 && new RegExp(`^ {0,3}${opening[1][0]}{${opening[1].length},}$`).test(closing);
    }
    if (id === 'task') ok = first.type === 'list' && !first.ordered && first.items.length === 2 && first.items.every((item, index) => item.task && item.checked === Boolean(index) && plain(item) === ['下書き', '確認'][index]);
    if (id === 'table') ok = first.type === 'table' && first.header.length === 2 && first.rows.length === 1 && first.header.map(plain).join('|') === '項目|内容' && first.rows[0].map(plain).join('|') === '日時|10時';
  }
  return { ok, message: ok ? '書けました。プレビューと記号を見比べてみましょう。' : lesson.hint };
}

export function insertSyntax(content, start, end, id) {
  const lesson = LESSONS.find(item => item.id === id);
  if (!lesson) return { content, start, end };
  start = Math.max(0, Math.min(content.length, start));
  end = Math.max(start, Math.min(content.length, end));
  let selection = content.slice(start, end);
  let replacement;
  let offset = 0;
  let selectedLength;
  if (id === 'bold' || id === 'link') {
    const word = selection || (id === 'bold' ? '大切なこと' : '参考資料');
    const opening = id === 'bold' ? '**' : '[';
    replacement = opening + word + (id === 'bold' ? '**' : '](https://example.com)');
    offset = opening.length;
    selectedLength = word.length;
  } else {
    start = start === 0 ? 0 : content.lastIndexOf('\n', start - 1) + 1;
    const nextLine = content.indexOf('\n', end);
    end = nextLine < 0 ? content.length : nextLine;
    selection = content.slice(start, end);
    if (['heading', 'list', 'quote', 'task'].includes(id)) {
      const defaults = { heading: '見出し', list: '項目', quote: '引用する言葉', task: 'やること' };
      const prefix = { heading: '## ', list: '- ', quote: '> ', task: '- [ ] ' }[id];
      replacement = (selection || defaults[id]).split('\n').map(line => prefix + (id === 'heading' ? line.replace(/^ {0,3}#{1,6}(?:[ \t]+|$)/, '') : line)).join('\n');
    } else if (id === 'code') {
      // A fence longer than any run in the selection keeps the selected text inside the block.
      const longest = Math.max(2, ...Array.from(selection.matchAll(/`+/g), match => match[0].length));
      const fence = '`'.repeat(longest + 1);
      replacement = `${fence}\n${selection || 'ここにコードを書く'}\n${fence}`;
    } else {
      // Place a table after the current line so insertion preserves existing prose.
      start = end;
      replacement = lesson.syntax;
    }
    const before = content.slice(0, start);
    const after = content.slice(end);
    const lead = !before || before.endsWith('\n\n') ? '' : before.endsWith('\n') ? '\n' : '\n\n';
    const tail = after && !after.startsWith('\n\n') ? '\n' : '';
    replacement = lead + replacement + tail;
    offset = lead.length;
    selectedLength = replacement.length - lead.length - tail.length;
  }
  const result = content.slice(0, start) + replacement + content.slice(end);
  if (result.length > MAX_LENGTH) throw new Error('文書は100,000文字までです。内容を減らしてから挿入してください。');
  return { content: result, start: start + offset, end: start + offset + selectedLength };
}

export function readDraft(raw) {
  if (raw === null) return null;
  const value = JSON.parse(raw);
  if (!value || value.version !== 1 || typeof value.title !== 'string' || value.title.length > 100 || typeof value.content !== 'string' || value.content.length > MAX_LENGTH || !Array.isArray(value.completed) || value.completed.some(id => !LESSONS.some(lesson => lesson.id === id))) throw new Error('下書きの形式が正しくありません。');
  return { title: value.title, content: value.content, completed: [...new Set(value.completed)] };
}
export function makeDraft(value) {
  const result = JSON.stringify({ version: 1, title: value.title, content: value.content, completed: [...value.completed] });
  readDraft(result);
  return result;
}
export function safeFilename(title) {
  const clean = title.replace(/[\u0000-\u001f\u007f<>:"/\\|?*]/g, '').replace(/\.md$/i, '').replace(/^[.\s]+|[.\s]+$/g, '').slice(0, 80);
  return `${clean || 'メモ'}.md`;
}
export async function readTextFile(file) {
  if (!/\.(md|markdown|txt)$/i.test(file.name)) throw new Error('.md、.markdown、.txtのファイルを選んでください。');
  if (file.size > 512000) throw new Error('ファイルは500KB以下にしてください。');
  let content;
  try { content = new TextDecoder('utf-8', { fatal: true }).decode(await file.arrayBuffer()); }
  catch { throw new Error('UTF-8のテキストを読み込めませんでした。文字コードを確認してください。'); }
  if (content.length > MAX_LENGTH) throw new Error('文書は100,000文字までです。');
  return content.replace(/\r\n?/g, '\n');
}
