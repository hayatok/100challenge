import { useEffect, useRef, useState } from 'react';
import type { CSSProperties, KeyboardEvent, PointerEvent } from 'react';
import type { Rect, WorkspaceController } from './types';
import './styles.css';

function Icon({ name, size = 20 }: { name: 'upload' | 'copy' | 'scan' | 'check' | 'undo' | 'redo' | 'download' | 'image' | 'shield' | 'close'; size?: number }) {
  const paths = {
    upload: 'M12 16V3m-5 5 5-5 5 5M4 15v5a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-5',
    copy: 'M9 5H5v16h12v-4M9 3h12v14H9z',
    scan: 'M8 3H3v5m13-5h5v5M3 16v5h5m13-5v5h-5M7 9h10M7 13h10M7 17h6',
    check: 'm5 12 4 4L19 6',
    undo: 'm9 4-5 5 5 5M4 9h9a7 7 0 0 1 7 7v4',
    redo: 'm15 4 5 5-5 5m5-5h-9a7 7 0 0 0-7 7v4',
    download: 'M12 3v13m-5-5 5 5 5-5M4 17v4h16v-4',
    image: 'M3 3h18v18H3zM3 17l6-6 4 4 3-3 5 5M15 7h.01',
    shield: 'm12 3 8 3v6c0 5-8 9-8 9s-8-4-8-9V6zM8 12l3 3 5-6',
    close: 'm6 6 12 12M6 18 18 6',
  };
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={paths[name]} /></svg>;
}

function columnLabel(index: number): string {
  let result = '';
  for (let n = index + 1; n > 0; n = Math.floor((n - 1) / 26)) result = String.fromCharCode(65 + (n - 1) % 26) + result;
  return result;
}

function boxStyle(box: Rect, width: number, height: number): CSSProperties {
  return { left: `${box.x / width * 100}%`, top: `${box.y / height * 100}%`, width: `${box.width / width * 100}%`, height: `${box.height / height * 100}%` };
}

export default function App({ controller }: { controller: WorkspaceController }) {
  const { state } = controller;
  const { source, crop, table, selected } = state;
  const fileInput = useRef<HTMLInputElement>(null);
  const imageElement = useRef<HTMLImageElement>(null);
  const grid = useRef<HTMLTableElement>(null);
  const pointerStart = useRef<{ x: number; y: number } | null>(null);
  const [draftCrop, setDraftCrop] = useState<Rect | null>(null);
  const [dragging, setDragging] = useState(false);
  const dragDepth = useRef(0);
  const busy = ['loading-image', 'loading-model', 'recognizing'].includes(state.phase);
  const rowCount = table?.cells.length ?? 0;
  const columnCount = table?.cells[0]?.length ?? 0;
  const reviewCount = table?.cells.flat().filter(cell => !cell.reviewed && cell.confidence < 0.85).length ?? 0;
  const selectedCell = selected ? table?.cells[selected.row]?.[selected.column] : null;
  const shownCrop = draftCrop ?? crop;
  const fullCrop = source ? crop ?? { x: 0, y: 0, width: source.width, height: source.height } : null;

  useEffect(() => {
    const onPaste = (event: ClipboardEvent) => {
      const target = event.target;
      if (target instanceof Element && target.closest('input, textarea, [contenteditable="true"]')) return;
      if (busy) return;
      const file = Array.from(event.clipboardData?.items ?? []).find(item => item.type.startsWith('image/'))?.getAsFile();
      if (file) { event.preventDefault(); void controller.loadFile(file); }
    };
    window.addEventListener('paste', onPaste);
    return () => window.removeEventListener('paste', onPaste);
  }, [busy, controller]);

  const openFile = () => fileInput.current?.click();
  const naturalPoint = (event: PointerEvent<HTMLDivElement>) => {
    const bounds = imageElement.current?.getBoundingClientRect();
    if (!bounds || !source) return null;
    return { x: Math.round(Math.max(0, Math.min(source.width, (event.clientX - bounds.left) / bounds.width * source.width))), y: Math.round(Math.max(0, Math.min(source.height, (event.clientY - bounds.top) / bounds.height * source.height))) };
  };
  const updateCrop = (start: { x: number; y: number }, end: { x: number; y: number }) => ({ x: Math.min(start.x, end.x), y: Math.min(start.y, end.y), width: Math.abs(start.x - end.x), height: Math.abs(start.y - end.y) });
  const changeCropNumber = (key: keyof Rect, value: number) => {
    if (!source || !fullCrop || !Number.isFinite(value)) return;
    const next = { ...fullCrop, [key]: Math.round(value) };
    next.x = Math.max(0, Math.min(source.width - 1, next.x));
    next.y = Math.max(0, Math.min(source.height - 1, next.y));
    next.width = Math.max(1, Math.min(source.width - next.x, next.width));
    next.height = Math.max(1, Math.min(source.height - next.y, next.height));
    controller.setCrop(next);
  };
  const navigateCell = (event: KeyboardEvent<HTMLTextAreaElement>, row: number, column: number) => {
    if (event.nativeEvent.isComposing || event.ctrlKey || event.metaKey) return;
    const target = event.currentTarget;
    const atStart = target.selectionStart === 0 && target.selectionEnd === 0;
    const atEnd = target.selectionStart === target.value.length && target.selectionEnd === target.value.length;
    let nextRow = row;
    let nextColumn = column;
    if (event.key === 'Tab') {
      const index = row * columnCount + column + (event.shiftKey ? -1 : 1);
      if (index < 0 || index >= rowCount * columnCount) return;
      nextRow = Math.floor(index / columnCount); nextColumn = index % columnCount;
    } else if (event.key === 'Enter' && !event.altKey) nextRow += event.shiftKey ? -1 : 1;
    else if (event.key === 'ArrowLeft' && atStart && !event.shiftKey && !event.altKey) nextColumn--;
    else if (event.key === 'ArrowRight' && atEnd && !event.shiftKey && !event.altKey) nextColumn++;
    else if (event.key === 'ArrowUp' && atStart && !event.shiftKey && !event.altKey) nextRow--;
    else if (event.key === 'ArrowDown' && atEnd && !event.shiftKey && !event.altKey) nextRow++;
    else return;
    if (nextRow < 0 || nextRow >= rowCount || nextColumn < 0 || nextColumn >= columnCount) {
      if (event.key === 'Enter') event.preventDefault();
      return;
    }
    event.preventDefault();
    grid.current?.querySelector<HTMLTextAreaElement>(`[data-row="${nextRow}"][data-column="${nextColumn}"]`)?.focus();
  };

  return <div className="app" onDragEnter={event => {
    if (Array.from(event.dataTransfer.types).includes('Files')) { event.preventDefault(); dragDepth.current++; if (!busy) setDragging(true); }
  }} onDragOver={event => { if (Array.from(event.dataTransfer.types).includes('Files')) event.preventDefault(); }} onDragLeave={event => {
    event.preventDefault(); dragDepth.current = Math.max(0, dragDepth.current - 1); if (!dragDepth.current) setDragging(false);
  }} onDrop={event => {
    if (!Array.from(event.dataTransfer.types).includes('Files')) return;
    event.preventDefault(); setDragging(false); dragDepth.current = 0;
    const file = event.dataTransfer.files[0]; if (file && !busy) void controller.loadFile(file);
  }}>
    <input ref={fileInput} className="visually-hidden" type="file" accept="image/png,image/jpeg,image/webp,image/bmp,.bmp" aria-label="表の画像を選ぶ" disabled={busy} onChange={event => { const file = event.target.files?.[0]; if (file) void controller.loadFile(file); event.target.value = ''; }} />
    <header className="app-header">
      <a className="wordmark" href="#main" aria-label="表のコピペ救出 作業エリアへ"><span className="brand-mark" aria-hidden="true"><i /><i /><i /><i /></span><span>表のコピペ<span className="wordmark-accent">救出</span></span></a>
      <span className="privacy"><Icon name="shield" size={17} />画像はこの端末内で処理</span>
    </header>
    <main id="main">
      <section className="intro" aria-labelledby="title">
        <div><p className="eyebrow">スクショの表を、使える表へ。</p><h1 id="title">もう、見ながら打ち直さない。</h1><p className="intro-description">画像を貼る。読み取る。直して、Excelやスプレッドシートへ。</p></div>
        <ol className="steps" aria-label="使い方"><li className={source ? 'complete' : 'current'}><span>1</span>画像を入れる</li><li className={table ? 'complete' : source ? 'current' : ''}><span>2</span>読み取り・修正</li><li className={table ? 'current' : ''}><span>3</span>表をコピー</li></ol>
      </section>
      <div className="workspace">
        <section className="source-panel panel" aria-labelledby="source-title">
          <div className="panel-heading"><div className="panel-title"><span className="section-number">01</span><h2 id="source-title">元の画像</h2></div>{source && <button className="button small" onClick={openFile} disabled={busy}><Icon name="upload" size={17} />画像を変更</button>}</div>
          {!source ? <div className="upload-empty">
            <div className="paper-illustration" aria-hidden="true"><div className="paper-top"><span /><span /></div><div className="paper-grid"><i /><i /><i /><i /><i /><i /><i /><i /><i /></div><span className="paper-corner"><Icon name="scan" size={25} /></span></div>
            <h3>その表、ここに貼り付け。</h3><p>スクリーンショットを <kbd>⌘</kbd> / <kbd>Ctrl</kbd> + <kbd>V</kbd><br />画像をドラッグしても始められます。</p>
            <button className="button primary upload-button" onClick={openFile} disabled={busy}><Icon name="upload" />画像ファイルを選ぶ</button>
            <span className="file-support">PNG・JPEG・WebP・BMP</span>
            <div className="sample-separator"><span>まずは試してみる</span></div>
            <button className="sample-button" onClick={() => void controller.loadSample()} disabled={busy}><span className="sample-thumbnail" aria-hidden="true">品名　数量<br />ノート　３</span><span><strong>日本語のサンプルを開く</strong><small>実際の画像を読み取ります</small></span><span aria-hidden="true">↗</span></button>
          </div> : <>
            <div className="source-meta"><span title={source.name}>{source.name}</span><span>{source.width.toLocaleString()} × {source.height.toLocaleString()} px</span></div>
            <div className="image-stage">
              <div className={`source-image-wrap ${busy ? 'is-busy' : ''}`} onPointerDown={event => {
                if (busy || event.button !== 0) return;
                const point = naturalPoint(event); if (!point) return;
                pointerStart.current = point; event.currentTarget.setPointerCapture(event.pointerId); setDraftCrop({ ...point, width: 0, height: 0 });
              }} onPointerMove={event => { if (!pointerStart.current) return; const point = naturalPoint(event); if (point) setDraftCrop(updateCrop(pointerStart.current, point)); }} onPointerUp={event => {
                const start = pointerStart.current; pointerStart.current = null;
                if (!start) return;
                const point = naturalPoint(event); if (point) { const rect = updateCrop(start, point); if (rect.width > 3 && rect.height > 3) controller.setCrop(rect); }
                setDraftCrop(null);
              }} onPointerCancel={() => { pointerStart.current = null; setDraftCrop(null); }}>
                <img ref={imageElement} src={source.url} alt={`読み取る表の画像：${source.name}`} draggable={false} />
                {shownCrop && <div className="crop-box" style={boxStyle(shownCrop, source.width, source.height)}><span>読み取り範囲</span><i /><i /><i /><i /></div>}
                {selectedCell?.box && !draftCrop && <div className="cell-source-box" style={boxStyle(selectedCell.box, source.width, source.height)} />}
              </div>
            </div>
            <div className="crop-tools"><p><span aria-hidden="true">⌖</span> 画像をドラッグして、表の範囲を指定</p><button className="text-button" onClick={() => controller.setCrop(null)} disabled={busy || !crop}>全体に戻す</button></div>
            <details className="crop-details"><summary>数値で読み取り範囲を指定</summary><div className="crop-inputs">{fullCrop && (['x', 'y', 'width', 'height'] as const).map(key => <label key={key}>{({ x: '左から', y: '上から', width: '幅', height: '高さ' })[key]}<span><input type="number" min={key === 'x' || key === 'y' ? 0 : 1} max={key === 'x' || key === 'width' ? source.width : source.height} value={fullCrop[key]} disabled={busy} onChange={event => changeCropNumber(key, event.target.valueAsNumber)} />px</span></label>)}</div></details>
            <div className="recognize-area"><button className="button primary recognize-button" disabled={busy} onClick={() => void controller.recognize()}><Icon name="scan" />{table ? 'この範囲を読み取り直す' : '表を読み取る'}<span aria-hidden="true">→</span></button><p>{table ? '読み取り直すと、現在の編集表を置き換えます。' : '横書き・印刷された文字と、罫線のある表が得意です。'}</p></div>
          </>}
          <div className="source-footnote"><Icon name="shield" size={16} /><p>画像や認識結果はサーバーへ送信しません。<br />初回は、このアプリから認識モデルを読み込みます。</p></div>
        </section>
        <section className={`result-panel panel ${table ? 'has-table' : ''}`} aria-labelledby="result-title">
          <div className="panel-heading"><div className="panel-title"><span className="section-number">02</span><h2 id="result-title">取り出した表</h2>{table && <span className="dimension-badge">{rowCount} 行 × {columnCount} 列</span>}</div><div className="history-controls"><button className="button icon-button" aria-label="元に戻す" title="元に戻す" disabled={busy || !state.canUndo} onClick={controller.undo}><Icon name="undo" size={18} /></button><button className="button icon-button" aria-label="やり直す" title="やり直す" disabled={busy || !state.canRedo} onClick={controller.redo}><Icon name="redo" size={18} /></button></div></div>
          {busy ? <div className="processing" role="status" aria-live="polite"><div className="scan-symbol"><Icon name="scan" size={35} /></div><p className="eyebrow">表を取り出しています</p><h3>{state.progress?.label ?? (state.phase === 'loading-image' ? '画像を準備しています' : state.phase === 'loading-model' ? '認識モデルを読み込み中' : '文字を読み取っています')}</h3><div className={`progress-track ${state.progress?.value == null ? 'indeterminate' : ''}`} role="progressbar" aria-label="読み取りの進捗" aria-valuemin={0} aria-valuemax={100} aria-valuenow={state.progress?.value == null ? undefined : Math.round(state.progress.value)}><span style={state.progress?.value == null ? undefined : { width: `${Math.max(0, Math.min(100, state.progress.value))}%` }} /></div><p>この端末内で処理しています。<br />初回のモデル読み込みには時間がかかることがあります。</p><button className="button" onClick={controller.cancel}>読み取りを中止</button></div> : null}
          {state.error && <div className="error-message" role="alert"><strong>操作を完了できませんでした</strong><p>{state.error}</p><div><button className="button small" disabled={busy || !source} onClick={() => void controller.recognize()}>もう一度読み取る</button><button className="button small" disabled={busy} onClick={controller.createManualTable}>空の表を作って入力</button></div></div>}
          {!busy && !table && <div className="result-empty"><div className="empty-table" aria-hidden="true"><div><span>A</span><span>B</span><span>C</span></div><i /><i /><i /></div><h3>{source ? '準備できました。表を読み取りましょう。' : '画像の中の表が、ここで編集できます。'}</h3><p>{source ? '左の「表を読み取る」を押してください。' : 'まずは左に、表の画像を入れてください。'}<br />読み取った文字を元画像と見比べて直せます。</p><span className="empty-note"><Icon name="copy" size={16} />Excel・Google スプレッドシートへ貼り付け</span><button className="text-button manual-button" onClick={controller.createManualTable}>空の表から手入力する</button></div>}
          {table && <div className={busy ? 'table-content muted-content' : 'table-content'}>
            <div className="table-toolbar"><div className="review-status">{reviewCount ? <><span className="review-dot">!</span><strong>{reviewCount} セルを要確認</strong></> : <><Icon name="check" size={17} /><strong>内容を確認してコピー</strong></>}<span>セルを押して修正できます</span></div></div>
            {table.warnings.length > 0 && <div className="table-warnings">{table.warnings.map((warning, index) => <p key={index}>{warning}</p>)}</div>}
            <div className="grid-scroll" tabIndex={0} aria-label="編集表。横にスクロールできます"><table className="editor-grid" ref={grid}><thead><tr><th className="grid-corner" scope="col"><span className="visually-hidden">行番号</span></th>{Array.from({ length: columnCount }, (_, column) => <th scope="col" key={column} className={selected?.column === column ? 'selected-header' : ''}>{columnLabel(column)}</th>)}</tr></thead><tbody>{table.cells.map((row, rowIndex) => <tr key={rowIndex}><th scope="row" className={selected?.row === rowIndex ? 'selected-header' : ''}>{rowIndex + 1}</th>{row.map((cell, columnIndex) => {
              const needsReview = !cell.reviewed && cell.confidence < 0.85;
              const active = selected?.row === rowIndex && selected?.column === columnIndex;
              return <td key={columnIndex} className={`${active ? 'active-cell' : ''} ${needsReview ? 'needs-review' : ''}`}><textarea rows={1} data-row={rowIndex} data-column={columnIndex} aria-label={`${columnLabel(columnIndex)}${rowIndex + 1}${needsReview ? '、要確認' : ''}`} title={needsReview ? `要確認・認識の信頼度 ${Math.round(cell.confidence * 100)}%` : undefined} value={cell.value} disabled={busy} onFocus={event => { controller.selectCell(rowIndex, columnIndex); event.currentTarget.scrollIntoView({ block: 'nearest', inline: 'nearest' }); }} onChange={event => controller.editCell(rowIndex, columnIndex, event.target.value)} onKeyDown={event => navigateCell(event, rowIndex, columnIndex)} />{needsReview && <span className="cell-warning" aria-hidden="true">!</span>}</td>;
            })}</tr>)}</tbody></table></div>
            <div className="grid-help"><span>{selected ? <><strong>{columnLabel(selected.column)}{selected.row + 1}</strong>{selectedCell && !selectedCell.reviewed ? `認識の信頼度 ${Math.round(selectedCell.confidence * 100)}%` : '編集済み'}</> : 'セルを選択して、元画像と見比べられます'}</span><span><kbd>Tab</kbd> 次のセル · <kbd>Enter</kbd> 下へ · <kbd>Alt + Enter</kbd> 改行</span></div>
            <details className="structure-tools"><summary>行・列を調整 <span>選択セルの位置に追加・削除</span></summary><div><button className="button small" disabled={busy || !selected} onClick={() => selected && controller.addRow(selected.row + 1)}>下に行を追加</button><button className="button small" disabled={busy || !selected} onClick={() => selected && controller.addColumn(selected.column + 1)}>右に列を追加</button><button className="button small danger" disabled={busy || !selected || rowCount <= 1} onClick={() => selected && controller.deleteRow(selected.row)}>選択行を削除</button><button className="button small danger" disabled={busy || !selected || columnCount <= 1} onClick={() => selected && controller.deleteColumn(selected.column)}>選択列を削除</button></div></details>
            <div className="export-area"><div><h3>直せたら、そのまま持ち出す。</h3><p>セルの区切り・改行を保って貼り付けられます。</p></div><div className="export-buttons"><button className="button" disabled={busy} onClick={controller.downloadCSV}><Icon name="download" size={18} />CSV保存</button><button className="button primary copy-button" disabled={busy} onClick={() => void controller.copyTable()}><Icon name="copy" />表をコピー</button></div><p className="export-safety">表計算の式になる先頭文字は、文字列として保護して出力します。</p></div>
          </div>}
          {state.notice && <div className="notice" role="status" aria-live="polite"><Icon name="check" size={18} /><span>{state.notice}</span></div>}
        </section>
      </div>
      <footer className="app-footer"><details className="engine-details"><summary>認識エンジン・対応範囲</summary><div className="engine-body"><label>処理方式<select value={state.engine} disabled={busy} onChange={event => controller.setEngine(event.target.value as 'auto' | 'webgpu' | 'wasm')}><option value="auto">自動選択（推奨）</option><option value="webgpu">WebGPU</option><option value="wasm">WASM（CPU）</option></select></label><p>{state.runtime ? <>前回の実行：検出 {state.runtime.detector} / 文字認識 {state.runtime.recognizer}<br />処理時間 {(state.runtime.elapsedMs / 1000).toFixed(1)} 秒</> : '実際に使用した処理方式は、読み取り後にここへ表示します。'}</p><p>横書きの印刷体を対象としています。複雑な結合セル・手書き・斜めの写真は、正しく復元できない場合があります。PDFは画像にしてから取り込んでください。</p></div></details>{source && <button className="text-button reset-button" disabled={busy} onClick={controller.reset}>作業をリセット</button>}<span className="footer-label">表のコピペ救出 / LOCAL WORKSPACE</span></footer>
    </main>
    {dragging && <div className="drop-overlay"><div><Icon name="upload" size={40} /><strong>画像をここにドロップ</strong><span>表の救出をはじめましょう</span></div></div>}
  </div>;
}
