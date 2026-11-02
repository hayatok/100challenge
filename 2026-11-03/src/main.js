import DOMPurify from 'dompurify';
import './style.css';
import { LESSONS, TEMPLATES, MAX_LENGTH, parseMarkdown, insertSyntax, checkExercise, readDraft, makeDraft, safeFilename, readTextFile } from './core.js';

const $ = (id) => document.getElementById(id);
const editor = $('editor');
const title = $('document-title');
const storageKey = 'kakikata-note:v1';
let completed = new Set();
let used = new Set();
let currentLesson = LESSONS[0].id;
let composing = false;
let saveTimer;
let renderTimer;
let lastInputTime = 0;
let history = [];
editor.maxLength = MAX_LENGTH;
$('exercise-answer').maxLength = 10000;

function action(message, error = false) {
  $('action-status').textContent = message;
  $('action-status').classList.toggle('is-error', error);
}
function save() {
  clearTimeout(saveTimer);
  saveTimer = undefined;
  try {
    localStorage.setItem(storageKey, makeDraft({ title: title.value, content: editor.value, completed: [...completed] }));
    $('save-status').textContent = '下書きを保存しました';
    $('save-status').classList.remove('is-error');
  } catch {
    $('save-status').textContent = '下書きを保存できません。.mdを保存して手元に残してください。';
    $('save-status').classList.add('is-error');
  }
}
function scheduleSave() {
  clearTimeout(saveTimer);
  $('save-status').textContent = '下書きを保存しています…';
  $('save-status').classList.remove('is-error');
  saveTimer = setTimeout(save, 450);
}
function updateLearning() {
  $('used-state').textContent = used.has(currentLesson) ? '本文で使用中' : '本文では未使用';
  $('used-state').classList.toggle('is-used', used.has(currentLesson));
  $('completed-state').textContent = completed.has(currentLesson) ? '練習を完了' : '練習は未完了';
  $('completed-state').classList.toggle('is-complete', completed.has(currentLesson));
  $('progress-count').textContent = `練習の完了 ${completed.size} / ${LESSONS.length}`;
  $('progress-markers').replaceChildren(...LESSONS.map((lesson) => {
    const marker = document.createElement('span');
    marker.className = completed.has(lesson.id) ? 'complete' : '';
    return marker;
  }));
}
function renderHtml(target, html) {
  target.innerHTML = DOMPurify.sanitize(html, { USE_PROFILES: { html: true }, FORBID_TAGS: ['img', 'video', 'audio', 'iframe', 'style', 'form', 'button'], FORBID_ATTR: ['style', 'id', 'name'] });
  target.querySelectorAll('a').forEach((link) => {
    link.target = '_blank';
    link.rel = 'noopener noreferrer';
  });
}
function renderExercise() {
  const value = $('exercise-answer').value;
  $('exercise-preview-wrap').hidden = !value.trim();
  renderHtml($('exercise-preview'), parseMarkdown(value).html);
}
function render() {
  clearTimeout(renderTimer);
  const parsed = parseMarkdown(editor.value);
  used = parsed.used;
  const preview = $('preview');
  if (editor.value.trim()) {
    renderHtml(preview, parsed.html);
    preview.classList.remove('is-empty');
  } else {
    preview.textContent = 'ここに文章の仕上がりが表示されます。入力欄から書き始めましょう。';
    preview.classList.add('is-empty');
  }
  $('character-count').textContent = `${editor.value.length.toLocaleString()} / ${MAX_LENGTH.toLocaleString()}文字`;
  updateLearning();
}
function checkpoint() {
  const snapshot = { title: title.value, content: editor.value, start: editor.selectionStart, end: editor.selectionEnd };
  const previous = history.at(-1);
  if (!previous || previous.content !== snapshot.content || previous.title !== snapshot.title) {
    history.push(snapshot);
    // Bound history by both entries and content size for long documents.
    while (history.length > 50 || (history.length > 1 && history.reduce((size, item) => size + item.content.length, 0) > 2000000)) history.shift();
  }
  $('undo').disabled = !history.length;
}
function resetTypingGroup() { lastInputTime = 0; }
function applyDocument(nextTitle, content) {
  if (content.length > MAX_LENGTH) { action(`本文は${MAX_LENGTH.toLocaleString()}文字までです。`, true); return; }
  checkpoint();
  resetTypingGroup();
  title.value = nextTitle;
  editor.value = content;
  editor.setSelectionRange(0, 0);
  render();
  scheduleSave();
}
function undo() {
  if (composing) return;
  const previous = history.pop();
  if (!previous) return;
  title.value = previous.title;
  editor.value = previous.content;
  editor.focus();
  editor.setSelectionRange(previous.start, previous.end);
  $('undo').disabled = !history.length;
  resetTypingGroup();
  render();
  scheduleSave();
  action('一つ前の編集に戻しました。');
}
function selectLesson(id) {
  currentLesson = id;
  const lesson = LESSONS.find((item) => item.id === id);
  $('lesson-select').value = id;
  $('lesson-summary').textContent = lesson.summary;
  $('lesson-syntax').textContent = lesson.syntax;
  $('lesson-explanation').textContent = lesson.explanation;
  $('extension-note').hidden = !lesson.extension;
  $('exercise-prompt').textContent = lesson.prompt;
  $('exercise-hint').textContent = lesson.hint;
  $('exercise-example').textContent = lesson.answer;
  $('exercise-answer').value = '';
  renderExercise();
  $('exercise-feedback').textContent = '';
  $('exercise-feedback').className = 'feedback';
  $('exercise').hidden = true;
  $('start-exercise').textContent = '自分で試す →';
  $('start-exercise').setAttribute('aria-expanded', 'false');
  $('answer-details').open = false;
  updateLearning();
}
for (const lesson of LESSONS) {
  const option = document.createElement('option');
  option.value = lesson.id;
  option.textContent = lesson.label;
  $('lesson-select').append(option);
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'format-button';
  button.title = `${lesson.label}を挿入`;
  button.setAttribute('aria-label', `${lesson.label}を挿入`);
  const symbol = document.createElement('span');
  symbol.className = 'format-symbol';
  symbol.textContent = lesson.symbol;
  const label = document.createElement('span');
  label.textContent = lesson.label;
  button.append(symbol, label);
  button.addEventListener('mousedown', (event) => event.preventDefault());
  button.addEventListener('click', () => {
    if (composing) return;
    let result;
    try { result = insertSyntax(editor.value, editor.selectionStart, editor.selectionEnd, lesson.id); }
    catch (error) { action(error.message, true); return; }
    if (result.content.length > MAX_LENGTH) { action(`挿入できません。本文は${MAX_LENGTH.toLocaleString()}文字までです。`, true); return; }
    checkpoint();
    resetTypingGroup();
    editor.value = result.content;
    setView('write');
    editor.focus();
    editor.setSelectionRange(result.start, result.end);
    selectLesson(lesson.id);
    render();
    scheduleSave();
    action(`${lesson.label}を挿入しました。書き方は手引きで確認できます。`);
  });
  $('format-buttons').append(button);
}
try {
  const draft = readDraft(localStorage.getItem(storageKey));
  title.value = draft?.title ?? TEMPLATES.memo.title;
  editor.value = draft?.content ?? TEMPLATES.memo.content;
  completed = new Set(draft?.completed ?? []);
  $('save-status').textContent = draft ? '保存した下書きを開きました' : '記入例のメモから始められます';
} catch {
  title.value = TEMPLATES.memo.title;
  editor.value = TEMPLATES.memo.content;
  $('save-status').textContent = '下書きを読み込めなかったため、記入例を開きました。';
  $('save-status').classList.add('is-error');
}
selectLesson(currentLesson);
render();
$('lesson-select').addEventListener('change', (event) => selectLesson(event.target.value));
$('start-exercise').setAttribute('aria-controls', 'exercise');
$('start-exercise').addEventListener('click', () => {
  const opening = $('exercise').hidden;
  $('exercise').hidden = !opening;
  $('start-exercise').textContent = opening ? '練習を閉じる ↑' : '自分で試す →';
  $('start-exercise').setAttribute('aria-expanded', String(opening));
  if (opening) $('exercise-answer').focus();
});
$('exercise-answer').addEventListener('input', (event) => {
  if (event.isComposing) return;
  $('exercise-feedback').textContent = '';
  renderExercise();
});
$('exercise-answer').addEventListener('compositionend', renderExercise);
$('check-exercise').addEventListener('click', () => {
  renderExercise();
  const result = checkExercise(currentLesson, $('exercise-answer').value);
  $('exercise-feedback').textContent = result.message;
  $('exercise-feedback').className = `feedback ${result.ok ? 'is-complete' : 'is-error'}`;
  if (result.ok) { completed.add(currentLesson); updateLearning(); scheduleSave(); }
});
editor.addEventListener('beforeinput', () => {
  if (composing) return;
  const now = Date.now();
  if (now - lastInputTime > 700) checkpoint();
  lastInputTime = now;
});
editor.addEventListener('input', () => {
  if (composing) return;
  clearTimeout(renderTimer);
  renderTimer = setTimeout(render, 100);
  scheduleSave();
});
editor.addEventListener('compositionstart', () => {
  checkpoint(); composing = true; clearTimeout(renderTimer); clearTimeout(saveTimer);
});
editor.addEventListener('compositionend', () => {
  composing = false;
  if (editor.value.length > MAX_LENGTH) editor.value = editor.value.slice(0, MAX_LENGTH);
  resetTypingGroup(); render(); scheduleSave();
});
title.addEventListener('beforeinput', () => { if (composing) return; if (Date.now() - lastInputTime > 700) checkpoint(); lastInputTime = Date.now(); });
title.addEventListener('input', () => { if (!composing) scheduleSave(); });
title.addEventListener('compositionstart', () => { checkpoint(); composing = true; clearTimeout(renderTimer); clearTimeout(saveTimer); });
title.addEventListener('compositionend', () => { composing = false; resetTypingGroup(); scheduleSave(); });
$('undo').addEventListener('click', undo);
document.addEventListener('keydown', (event) => {
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'z' && !event.shiftKey && (event.target === editor || event.target === title)) { event.preventDefault(); undo(); }
});
let resolveReplacement;
function confirmReplacement() {
  $('replace-dialog').showModal();
  return new Promise(resolve => { resolveReplacement = resolve; });
}
function finishReplacement(accepted) {
  $('replace-dialog').close();
  resolveReplacement?.(accepted);
  resolveReplacement = undefined;
}
$('replace-cancel').addEventListener('click', () => finishReplacement(false));
$('replace-confirm').addEventListener('click', () => finishReplacement(true));
$('replace-dialog').addEventListener('cancel', event => { event.preventDefault(); finishReplacement(false); });
$('template-select').addEventListener('change', async (event) => {
  const template = TEMPLATES[event.target.value];
  event.target.value = '';
  if (!template || !await confirmReplacement()) return;
  applyDocument(template.title, template.content);
  action('ひな形を開きました。内容を書き換えて使えます。');
});
$('open-file').addEventListener('click', () => $('file-input').click());
$('file-input').addEventListener('change', async (event) => {
  const file = event.target.files?.[0];
  event.target.value = '';
  if (!file) return;
  action('ファイルを読み込んでいます…');
  try {
    const content = await readTextFile(file);
    if (content.length > MAX_LENGTH) throw new Error(`本文は${MAX_LENGTH.toLocaleString()}文字までです。`);
    if (!await confirmReplacement()) { action('ファイルを開く操作を取り消しました。'); return; }
    applyDocument(file.name.replace(/\.(md|markdown|txt)$/i, '').slice(0, 100), content);
    action('ファイルを開きました。');
  } catch (error) { action(`ファイルを開けませんでした。${error.message}`, true); }
});
$('copy-document').addEventListener('click', async () => {
  try { await navigator.clipboard.writeText(editor.value); action('Markdownをコピーしました。'); }
  catch { setView('write'); editor.focus(); editor.select(); action('自動でコピーできませんでした。本文を選択しました。コピー操作（Ctrl+C / ⌘C）を行ってください。', true); }
});
$('download-document').addEventListener('click', () => {
  const url = URL.createObjectURL(new Blob([editor.value], { type: 'text/markdown;charset=utf-8' }));
  const link = document.createElement('a');
  link.href = url; link.download = safeFilename(title.value); document.body.append(link); link.click(); link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
  action('Markdownファイルの保存を開始しました。');
});
function setView(view) {
  document.querySelector('.panes').dataset.view = view;
  for (const name of ['write', 'preview']) {
    const selected = name === view;
    $(`${name}-tab`).setAttribute('aria-selected', String(selected));
    $(`${name}-tab`).tabIndex = selected ? 0 : -1;
  }
}
for (const view of ['write', 'preview']) {
  $(`${view}-tab`).addEventListener('click', () => setView(view));
  $(`${view}-tab`).addEventListener('keydown', (event) => {
    if (['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) { event.preventDefault(); const target = event.key === 'Home' ? 'write' : event.key === 'End' ? 'preview' : view === 'write' ? 'preview' : 'write'; setView(target); $(`${target}-tab`).focus(); }
  });
}
window.addEventListener('pagehide', () => { if (saveTimer && !composing) save(); });
