import { useCallback, useEffect, useRef, useState, type DragEvent } from 'react';
import { createDemoFile, exportClip, loadAudioFile, prepareEncoders, MAX_FILE_BYTES, MAX_DURATION, type AudioAsset, type ExportFormat } from './audio/engine';
import { formatTime, makeOutputFileName, parseTime, selectionError } from './audio/time';
import { usePlayback } from './audio/usePlayback';
import { Waveform } from './components/Waveform';

type Range = { start: number; end: number };
type Output = { url: string; name: string; size: number; format: ExportFormat; duration: number };
const errorMessage = (error: unknown) => error instanceof Error ? error.message : '処理できませんでした。もう一度お試しください。';
const fileSize = (bytes: number) => bytes >= 1024 * 1024 ? `${(bytes / 1024 / 1024).toFixed(1)} MB` : `${Math.max(1, Math.round(bytes / 1024))} KB`;

export default function App() {
  const [encoder, setEncoder] = useState<'loading' | 'ready' | 'error'>('loading');
  const [encoderError, setEncoderError] = useState('');
  const [asset, setAsset] = useState<AudioAsset | null>(null);
  const [loading, setLoading] = useState(false);
  const [loadError, setLoadError] = useState('');
  const [notice, setNotice] = useState('');
  const [dragOver, setDragOver] = useState(false);
  const [range, setRange] = useState<Range>({ start: 0, end: 0 });
  const [startText, setStartText] = useState('00:00.000');
  const [endText, setEndText] = useState('00:00.000');
  const [loop, setLoop] = useState(false);
  const [format, setFormat] = useState<ExportFormat>('mp3');
  const [bitrate, setBitrate] = useState(192);
  const [nameText, setNameText] = useState('');
  const [customName, setCustomName] = useState(false);
  const [encoding, setEncoding] = useState(false);
  const [progress, setProgress] = useState(0);
  const [exportError, setExportError] = useState('');
  const [output, setOutput] = useState<Output | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);
  const outputAudio = useRef<HTMLAudioElement>(null);
  const loadController = useRef<AbortController | null>(null);
  const exportController = useRef<AbortController | null>(null);
  const loadJob = useRef(0);
  const exportJob = useRef(0);
  const prepareJob = useRef(0);
  const start = parseTime(startText);
  const end = parseTime(endText);
  const rangeError = asset ? selectionError(start, end, asset.duration) : null;
  const playback = usePlayback(asset?.buffer ?? null, range, loop);

  const prepare = useCallback(async () => {
    const job = ++prepareJob.current;
    setEncoder('loading'); setEncoderError('');
    try {
      await prepareEncoders();
      if (job === prepareJob.current) setEncoder('ready');
    } catch (error) {
      if (job === prepareJob.current) { setEncoder('error'); setEncoderError(errorMessage(error)); }
    }
  }, []);
  useEffect(() => { void prepare(); return () => { ++prepareJob.current; }; }, [prepare]);
  useEffect(() => () => { ++loadJob.current; ++exportJob.current; loadController.current?.abort(); exportController.current?.abort(); }, []);
  useEffect(() => () => { if (output) URL.revokeObjectURL(output.url); }, [output]);
  useEffect(() => {
    if (asset && !customName) setNameText(makeOutputFileName(asset.fileName, range.start, range.end, format));
  }, [asset, customName, range, format]);

  function invalidateOutput() {
    ++exportJob.current;
    exportController.current?.abort(); exportController.current = null;
    setEncoding(false); setOutput(null); setExportError(''); setProgress(0); setNotice('');
  }
  function changeRange(next: Range) {
    playback.stop(); invalidateOutput(); setRange(next);
    setStartText(formatTime(next.start)); setEndText(formatTime(next.end));
  }
  function editTime(which: 'start' | 'end', value: string) {
    playback.stop(); invalidateOutput();
    const nextStart = which === 'start' ? parseTime(value) : start;
    const nextEnd = which === 'end' ? parseTime(value) : end;
    if (which === 'start') setStartText(value); else setEndText(value);
    if (asset && !selectionError(nextStart, nextEnd, asset.duration) && nextStart !== null && nextEnd !== null) setRange({ start: nextStart, end: nextEnd });
  }
  async function openFile(file: File) {
    playback.stop(); invalidateOutput();
    loadController.current?.abort();
    const controller = new AbortController(); loadController.current = controller;
    const job = ++loadJob.current;
    setLoading(true); setLoadError(''); setAsset(null); setCustomName(false);
    try {
      const loaded = await loadAudioFile(file, controller.signal);
      if (job !== loadJob.current || controller.signal.aborted) return;
      setAsset(loaded); setRange({ start: 0, end: loaded.duration });
      setStartText(formatTime(0)); setEndText(formatTime(loaded.duration));
      setNameText(makeOutputFileName(loaded.fileName, 0, loaded.duration, format));
    } catch (error) {
      if (job === loadJob.current && !controller.signal.aborted) setLoadError(errorMessage(error));
    } finally {
      if (job === loadJob.current) { setLoading(false); loadController.current = null; }
    }
  }
  function cancelLoad() {
    ++loadJob.current; loadController.current?.abort(); loadController.current = null;
    setLoading(false); setNotice('読み込みをキャンセルしました。ファイルを選び直せます。');
  }
  function onDrop(event: DragEvent) {
    event.preventDefault(); setDragOver(false);
    const file = event.dataTransfer.files[0];
    if (file) void openFile(file);
  }
  function changeFormat(next: ExportFormat) {
    invalidateOutput(); setFormat(next);
    if (customName) setNameText(value => `${value.replace(/\.(mp3|m4a)$/i, '')}.${next}`);
  }
  const trimmedName = nameText.trim();
  const nameError = !trimmedName ? '保存するファイル名を入力してください。' : /[<>:"/\\|?*]/.test(trimmedName) || Array.from(trimmedName).some(char => char.charCodeAt(0) < 32 || char.charCodeAt(0) === 127) || /^\.+$/.test(trimmedName) ? 'ファイル名に使えない記号が含まれています。' : null;
  async function saveClip() {
    if (!asset || rangeError || nameError || encoder !== 'ready' || encoding) return;
    playback.stop(); invalidateOutput();
    const controller = new AbortController(); exportController.current = controller;
    const job = ++exportJob.current;
    setEncoding(true); setExportError(''); setProgress(0);
    try {
      const blob = await exportClip(asset.buffer, { ...range, format, bitrate, signal: controller.signal, onProgress: value => {
        if (job === exportJob.current) setProgress(Math.min(1, Math.max(0, value)));
      } });
      if (job !== exportJob.current || controller.signal.aborted) return;
      const name = trimmedName.toLowerCase().endsWith(`.${format}`) ? trimmedName : `${trimmedName.replace(/\.(mp3|m4a)$/i, '')}.${format}`;
      setOutput({ url: URL.createObjectURL(blob), name, size: blob.size, format, duration: range.end - range.start });
      setProgress(1);
    } catch (error) {
      if (job === exportJob.current && !controller.signal.aborted) setExportError(errorMessage(error));
    } finally {
      if (job === exportJob.current) { setEncoding(false); exportController.current = null; }
    }
  }
  function cancelExport() {
    invalidateOutput(); setNotice('書き出しをキャンセルしました。設定を確認して、もう一度書き出せます。');
  }
  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      const target = event.target as HTMLElement;
      if (event.code !== 'Space' || event.repeat || target.closest('input, textarea, select, button, audio, a, [contenteditable="true"]')) return;
      if (!asset || rangeError || loading || encoding) return;
      event.preventDefault(); outputAudio.current?.pause(); void playback.toggle();
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [asset, rangeError, loading, encoding, playback.toggle]);

  return <div className="app-shell">
    <header className="app-header">
      <div className="brand"><span className="brand-mark" aria-hidden="true">✂</span><span>端末内の音声ツール</span></div>
      <span className="local-label">アップロードなし</span>
    </header>
    <main>
      <div className="intro">
        <h1>音声の切り出し</h1>
        <p>必要なところを選んで、聴いて、保存。</p>
      </div>
      <div className={`encoder-status ${encoder === 'ready' ? 'status-success' : encoder === 'error' ? 'status-error' : ''}`} role="status">
        <span className="status-dot" aria-hidden="true" />
        <span>{encoder === 'ready' ? '準備完了 — 通信を切っても編集・保存できます。' : encoder === 'loading' ? '音声処理の準備中… ファイルは先に選べます。' : `音声処理を準備できませんでした。${encoderError}`}</span>
        {encoder === 'error' && <button type="button" onClick={() => void prepare()}>準備を再試行</button>}
      </div>
      <section className={`file-section${dragOver ? ' is-dragover' : ''}${asset ? ' has-file' : ''}`} aria-labelledby="file-heading" onDragOver={event => { event.preventDefault(); setDragOver(true); }} onDragLeave={event => { if (!event.currentTarget.contains(event.relatedTarget as Node)) setDragOver(false); }} onDrop={onDrop}>
        <div className="section-label"><span className="step">01</span><h2 id="file-heading">音声を開く</h2></div>
        <input ref={fileInput} className="visually-hidden" type="file" accept="audio/*,.mp3,.m4a,.aac,.wav,.ogg,.flac,.webm,.mp4" aria-label="音声ファイル" onChange={event => {
          const file = event.currentTarget.files?.[0]; event.currentTarget.value = ''; if (file) void openFile(file);
        }} />
        {asset ? <div className="file-info"><strong>{asset.fileName}</strong><p className="hint">{formatTime(asset.duration)} <span>／</span> {asset.channels === 1 ? 'モノラル' : 'ステレオ'} <span>／</span> 編集 {(asset.sampleRate / 1000).toLocaleString('ja-JP')} kHz <span>／</span> {fileSize(asset.fileSize)}</p></div>
          : <div className="file-prompt"><p>{loading ? '音声を読み込んでいます…' : 'ここに音声ファイルをドロップ'}</p><p className="hint">{loading ? 'ファイルの長さによって、少し時間がかかります。' : 'または、下のボタンから選んでください。'}</p></div>}
        <div className="file-actions">
          <button type="button" className={asset ? '' : 'primary'} onClick={() => fileInput.current?.click()}>{asset || loading ? '別のファイルを選ぶ' : '音声ファイルを選ぶ'}</button>
          {loading ? <button type="button" onClick={cancelLoad}>読み込みをキャンセル</button> : !asset && <button type="button" onClick={() => void openFile(createDemoFile())}>生成サンプルで試す（8秒）</button>}
        </div>
        <p className="hint file-limit">{MAX_FILE_BYTES / 1024 / 1024} MBまで・{MAX_DURATION / 60}分まで・モノラル／ステレオ。ブラウザが読み込める音声に対応。</p>
        {loadError && <p className="error-message" role="alert">{loadError} 別のファイルを選んでお試しください。</p>}
      </section>
      {asset && <>
        <section className="editor-section" aria-labelledby="selection-heading">
          <div className="section-heading"><div className="section-label"><span className="step">02</span><h2 id="selection-heading">残す範囲を選ぶ</h2></div><button type="button" className="small-button" disabled={encoding} onClick={() => changeRange({ start: 0, end: asset.duration })}>範囲をリセット</button></div>
          <Waveform key={asset.fileName + asset.duration} buffer={asset.buffer} selection={range} position={playback.position} disabled={encoding} onChange={changeRange} />
          <div className="time-controls">
            <label>開始時刻<input className="mono" type="text" inputMode="decimal" value={startText} disabled={encoding} aria-invalid={!!rangeError} aria-describedby={rangeError ? 'range-error time-help' : 'time-help'} onChange={event => editTime('start', event.target.value)} /></label>
            <span className="time-separator" aria-hidden="true">→</span>
            <label>終了時刻<input className="mono" type="text" inputMode="decimal" value={endText} disabled={encoding} aria-invalid={!!rangeError} aria-describedby={rangeError ? 'range-error time-help' : 'time-help'} onChange={event => editTime('end', event.target.value)} /></label>
            <div className="selection-duration"><span>選択時間</span><strong className="mono">{rangeError ? '—' : formatTime(range.end - range.start)}</strong></div>
          </div>
          <p className="hint" id="time-help">分:秒.ミリ秒、または秒で入力（例 01:23.456 / 83.456）。0.02秒以上の範囲を選べます。</p>
          {rangeError && <p className="error-message" id="range-error" role="alert">{rangeError}</p>}
          <div className="playback-controls">
            <button type="button" className="play-button" disabled={!!rangeError || encoding} onClick={() => { outputAudio.current?.pause(); void playback.toggle(); }}><span aria-hidden="true">{playback.playing ? '■' : '▶'}</span> {playback.playing ? '停止' : '選択範囲を試聴'}</button>
            <label className="checkbox-label"><input type="checkbox" checked={loop} disabled={encoding} onChange={event => setLoop(event.target.checked)} />ループ再生</label>
            <span className="hint shortcut">Space でも再生・停止</span>
          </div>
          {playback.error && <p className="error-message" role="alert">{playback.error}</p>}
        </section>
        <section className="export-section" aria-labelledby="export-heading">
          <div className="section-label"><span className="step">03</span><h2 id="export-heading">形式を選んで保存</h2></div>
          <div className="export-settings">
            <fieldset disabled={encoding}><legend>保存形式</legend><div className="format-options">{(['mp3', 'm4a'] as const).map(value => <label className={`format-option${format === value ? ' selected' : ''}`} key={value}><input type="radio" name="format" value={value} checked={format === value} onChange={() => changeFormat(value)} /><span>{value === 'mp3' ? 'MP3' : 'M4A (AAC)'}</span></label>)}</div></fieldset>
            <label className="quality-field">音質<select value={bitrate} disabled={encoding} onChange={event => { invalidateOutput(); setBitrate(Number(event.target.value)); }}><option value={128}>128 kbps</option><option value={192}>192 kbps（標準）</option><option value={256}>256 kbps</option></select></label>
          </div>
          <label className="filename-field">保存ファイル名<input type="text" value={nameText} disabled={encoding} aria-invalid={!!nameError} aria-describedby={nameError ? 'name-error' : undefined} onChange={event => { invalidateOutput(); setCustomName(true); setNameText(event.target.value); }} /></label>
          {nameError && <p className="error-message" id="name-error" role="alert">{nameError}</p>}
          <div className="save-row">
            {encoding ? <><div className="progress-block" role="status"><span>書き出し中… {Math.round(progress * 100)}%</span><progress max="1" value={progress} aria-label="書き出し進捗" /></div><button type="button" onClick={cancelExport}>書き出しをキャンセル</button></> : <><button type="button" className="primary save-button" disabled={!!rangeError || !!nameError || encoder !== 'ready'} onClick={() => void saveClip()}>{exportError ? 'もう一度書き出す' : `${format.toUpperCase()}を書き出す`}</button><span className="hint">{encoder !== 'ready' ? '音声処理の準備完了後に書き出せます。' : rangeError ? '時刻を修正すると書き出せます。' : '端末内で変換してから、保存できます。'}</span></>}
          </div>
          <p className="hint export-padding-note">圧縮形式のため、出力に数十ミリ秒の余白が付く場合があります。</p>
          {exportError && <p className="error-message" role="alert">書き出せませんでした。{exportError} 設定を確認して再試行してください。</p>}
          {output && <div className="output-result"><p className="success-message" role="status">書き出しが完了しました</p><strong className="output-name">{output.name}</strong><p className="hint">{output.format === 'm4a' ? 'M4A / AAC' : 'MP3'} ／ 選択範囲 {formatTime(output.duration)} ／ {fileSize(output.size)}</p><label className="output-audio-label">書き出した音声を確認<audio ref={outputAudio} onPlay={() => playback.stop()} controls src={output.url} aria-label="書き出した音声を確認" preload="metadata" /></label><a className="button primary download-button" href={output.url} download={output.name}>ファイルを保存</a></div>}
        </section>
      </>}
      {notice && <p className="notice" role="status">{notice}</p>}
    </main>
    <footer><p>音声・ファイル名・編集内容は外部へ送信せず、この画面を閉じると破棄します。</p><a href="./licenses.html" target="_blank" rel="noreferrer">使用ライブラリのライセンス</a></footer>
  </div>;
}
