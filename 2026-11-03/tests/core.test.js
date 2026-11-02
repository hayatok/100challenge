import { test } from 'node:test';
import assert from 'node:assert/strict';
import { LESSONS, MAX_LENGTH, parseMarkdown, checkExercise, insertSyntax, readDraft, makeDraft, readTextFile, safeFilename } from '../src/core.js';

for (const lesson of LESSONS) {
  test(`${lesson.id}: 課題の解答と平文の誤答を区別する`, () => {
    assert.equal(checkExercise(lesson.id, lesson.answer).ok, true);
    assert.equal(checkExercise(lesson.id, '').ok, false);
    assert.equal(checkExercise(lesson.id, '準備 必須 ノート ペン 参考資料 急がば回れ。 npm install 下書き 確認 日時 10時').ok, false);
  });
}
test('コード内とエスケープした記号は本文で使用した記法に数えない', () => {
  assert.deepEqual([...parseMarkdown('```md\n## 見出し\n**必須**\n- [ ] タスク\n```').used], ['code']);
  assert.equal(parseMarkdown('\\# 見出し\n\n\\*\\*太字\\*\\*').used.size, 0);
});
test('練習は指定内容・状態・フェンスの閉鎖まで確認する', () => {
  for (const [id, input] of [['heading', '# 準備'], ['bold', '**これは必須です。**'], ['list', '1. ノート\n2. ペン'], ['link', '[参考資料](https://wrong.example)'], ['code', '```sh\nnpm install'], ['task', '- [x] 下書き\n- [ ] 確認'], ['table', '| 項目 | 内容 |\n| 日時 | 10時 |']]) assert.equal(checkExercise(id, input).ok, false, id);
  assert.equal(checkExercise('bold', 'これは __必須__ です。').ok, true);
  assert.equal(checkExercise('list', '* ノート\n* ペン').ok, true);
  assert.equal(checkExercise('code', '~~~sh\nnpm install\n~~~').ok, true);
});
test('生HTMLを文字として扱い、画像URLを自動取得しない', () => {
  const { html } = parseMarkdown('<script>alert(1)</script>\n\n![図](https://example.com/track.png)');
  assert.ok(!html.includes('<script>'));
  assert.ok(html.includes('&lt;script&gt;'));
  assert.ok(!html.includes('<img'));
  assert.ok(!html.includes('track.png'));
});
test('選択した語だけを囲み、前後の本文と選択範囲を保持する', () => {
  const result = insertSyntax('これは必須です。', 3, 5, 'bold');
  assert.equal(result.content, 'これは**必須**です。');
  assert.equal(result.content.slice(result.start, result.end), '必須');
});
test('行に書式を付けても前後の段落が混ざらず、コード中のフェンスを閉じない', () => {
  const result = insertSyntax('前\n準備\n後', 2, 4, 'heading');
  assert.equal(result.content, '前\n\n## 準備\n\n後');
  const code = insertSyntax('a```b', 0, 5, 'code').content;
  assert.ok(code.startsWith('````\n'));
  assert.equal(parseMarkdown(code).html.includes('a```b'), true);
  assert.throws(() => insertSyntax('a'.repeat(MAX_LENGTH), 1, 1, 'bold'));
});
test('下書きの形式・サイズ・練習IDを検証し、重複を除く', () => {
  const draft = { title: 'メモ', content: '# メモ', completed: ['heading'] };
  assert.deepEqual(readDraft(makeDraft(draft)), draft);
  assert.equal(readDraft(null), null);
  for (const value of ['{}', 'null', '{', JSON.stringify({ version: 1, title: 'x', content: '', completed: ['unknown'] })]) assert.throws(() => readDraft(value));
  assert.throws(() => makeDraft({ ...draft, content: 'a'.repeat(MAX_LENGTH + 1) }));
});
test('ファイル名を制限し、UTF-8・拡張子・サイズを確認する', async () => {
  assert.equal(safeFilename('../作業:メモ.md'), '作業メモ.md');
  assert.equal(safeFilename('...'), 'メモ.md');
  assert.equal(await readTextFile(new File(['# メモ\r\n本文'], 'memo.md')), '# メモ\n本文');
  await assert.rejects(readTextFile(new File([new Uint8Array([0xff])], 'bad.md')));
  await assert.rejects(readTextFile(new File(['x'], 'bad.exe')));
  await assert.rejects(readTextFile(new File(['x'.repeat(512001)], 'large.md')));
});

test('表の挿入で入力済みの行を消さない', () => {
  const result = insertSyntax('残したい本文', 2, 2, 'table');
  assert.ok(result.content.startsWith('残したい本文\n\n| 項目'));
});

test('4文字の字下げを採点時に削らず、プレビューと同じ意味で判定する', () => {
  assert.equal(checkExercise('heading', '    ## 準備').ok, false);
  assert.ok(parseMarkdown('    ## 準備').html.includes('<code>'));
  assert.equal(checkExercise('heading', '\n## 準備\n\n').ok, true);
  assert.equal(checkExercise('code', '    ```sh\n    npm install\n    ```').ok, false);
  assert.equal(checkExercise('code', '\n```sh\nnpm install\n```\n\n').ok, true);
});
