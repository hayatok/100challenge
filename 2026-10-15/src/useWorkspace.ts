import { useEffect, useRef, useState } from 'react';
import type { Rect, TableData, WorkspaceController, WorkspaceState } from './types';
import { addColumn, addRow, createBlankTable, deleteColumn, deleteRow, editCell, reconstructTable, toCSV, toHTML, toTSV } from './domain/table';
import { detectGrid } from './domain/grid';
import { startOcr, disposeOcr } from './ocr/engine';
import { clampCrop, createSampleFile, decodeFile, prepareRegion } from './images';

const initialState: WorkspaceState = {
  source: null, crop: null, table: null, selected: null, phase: 'idle', progress: null,
  error: null, notice: null, engine: 'auto', runtime: null, canUndo: false, canRedo: false,
};

export function useWorkspace(): WorkspaceController {
  const [state, setState] = useState<WorkspaceState>(initialState);
  const current = useRef(state);
  const generation = useRef(0);
  const pending = useRef<{ cancel(): void } | null>(null);
  const history = useRef<{ past: TableData[]; future: TableData[] }>({ past: [], future: [] });
  const grouping = useRef({ key: '', time: 0 });

  function update(patch: Partial<WorkspaceState>) {
    const next = { ...current.current, ...patch };
    current.current = next;
    setState(next);
  }

  useEffect(() => () => {
    generation.current++;
    pending.current?.cancel();
    disposeOcr();
    if (current.current.source) URL.revokeObjectURL(current.current.source.url);
  }, []);

  function stop() { generation.current++; pending.current?.cancel(); pending.current = null; }
  function clearHistory() { history.current = { past: [], future: [] }; grouping.current = { key: '', time: 0 }; }
  function commit(next: TableData, key = '') {
    const before = current.current.table;
    if (!before) return;
    const now = performance.now();
    if (!key || grouping.current.key !== key || now - grouping.current.time > 800) {
      history.current.past.push(before);
      if (history.current.past.length > 60) history.current.past.shift();
    }
    history.current.future = [];
    grouping.current = { key, time: now };
    const selected = current.current.selected;
    update({ table: next, canUndo: history.current.past.length > 0, canRedo: false, notice: null,
      selected: selected ? { row: Math.min(selected.row, next.cells.length - 1), column: Math.min(selected.column, next.cells[0].length - 1) } : null });
  }
  function modify(action: (table: TableData) => TableData, key = '') {
    if (!current.current.table) return;
    try { commit(action(current.current.table), key); }
    catch (error) { update({ error: getError(error) }); }
  }

  async function loadFile(file: File) {
    stop();
    const id = generation.current;
    update({ phase: 'loading-image', progress: { label: '画像を開いています', value: null }, error: null, notice: null });
    try {
      const source = await decodeFile(file);
      if (id !== generation.current) { URL.revokeObjectURL(source.url); return; }
      if (current.current.source) URL.revokeObjectURL(current.current.source.url);
      clearHistory();
      update({ source, crop: null, table: null, selected: null, runtime: null, phase: 'idle', progress: null, canUndo: false, canRedo: false });
    } catch (error) {
      if (id !== generation.current) return;
      update({ phase: 'error', progress: null, error: getError(error) });
    }
  }

  async function recognize() {
    const { source, crop, engine } = current.current;
    if (!source) return;
    stop();
    const id = generation.current;
    update({ phase: 'recognizing', progress: { label: '表の画像を準備しています', value: null }, error: null, notice: null, runtime: null });
    try {
      const region = await prepareRegion(source, crop);
      if (id !== generation.current) return;
      const hints = detectGrid(region.pixels, region.width, region.height);
      const job = startOcr(region.blob, engine, progress => {
        if (id !== generation.current) return;
        update({ phase: /読込|読み込|準備|モデル/.test(progress.label) ? 'loading-model' : 'recognizing', progress });
      });
      pending.current = job;
      const result = await job.promise;
      if (id !== generation.current) return;
      pending.current = null;
      if (result.tokens.length === 0) throw new Error('文字が見つかりませんでした。表を大きく切り抜くか、明るく鮮明な画像で試してください。手動で表を作ることもできます。');
      const table = reconstructTable(result.tokens, region.width, region.height, hints);
      table.cells.forEach(row => row.forEach(cell => {
        if (cell.box) cell.box = { x: region.region.x + cell.box.x * region.scaleX, y: region.region.y + cell.box.y * region.scaleY, width: cell.box.width * region.scaleX, height: cell.box.height * region.scaleY };
      }));
      table.rowEdges = table.rowEdges.map(value => region.region.y + value * region.scaleY);
      table.columnEdges = table.columnEdges.map(value => region.region.x + value * region.scaleX);
      clearHistory();
      update({ table, selected: { row: 0, column: 0 }, runtime: result.runtime, phase: 'ready', progress: null, error: null, notice: '表を取り出しました。元画像と見比べて、文字とセルの位置を確認してください。', canUndo: false, canRedo: false });
    } catch (error) {
      if (id !== generation.current) return;
      pending.current = null;
      update({ phase: 'error', progress: null, error: getError(error) });
    }
  }

  async function copyTable() {
    const table = current.current.table;
    if (!table) return;
    try {
      const text = toTSV(table);
      if (!navigator.clipboard) throw new Error('この環境ではクリップボードを使えません。CSV保存をお使いください。');
      if (typeof ClipboardItem !== 'undefined') {
        try {
          await navigator.clipboard.write([new ClipboardItem({ 'text/plain': new Blob([text], { type: 'text/plain' }), 'text/html': new Blob([toHTML(table)], { type: 'text/html' }) })]);
        } catch {
          await navigator.clipboard.writeText(text);
        }
      } else await navigator.clipboard.writeText(text);
      update({ notice: 'コピーしました。Excelやスプレッドシートのセルに貼り付けてください。', error: null });
    } catch (error) {
      update({ notice: null, error: error instanceof Error && error.message.includes('CSV') ? error.message : 'コピーできませんでした。ブラウザのコピー許可を確認するか、CSV保存をお使いください。' });
    }
  }

  function downloadCSV() {
    const { table, source } = current.current;
    if (!table) return;
    const url = URL.createObjectURL(new Blob([toCSV(table)], { type: 'text/csv;charset=utf-8' }));
    const link = document.createElement('a');
    link.href = url;
    link.download = `${(source?.name ?? '表').replace(/\.[^.]+$/, '').replace(/[\\/:*?"<>|\r\n]/g, '_')}-救出.csv`;
    link.click();
    window.setTimeout(() => URL.revokeObjectURL(url), 1000);
    update({ notice: 'CSVを保存しました。文字化けを防ぐUTF-8形式です。', error: null });
  }

  return {
    state,
    loadFile,
    async loadSample() { try { await loadFile(await createSampleFile()); } catch (error) { update({ error: getError(error), phase: 'error' }); } },
    setCrop(rect: Rect | null) {
      if (!current.current.source) return;
      try { update({ crop: rect ? clampCrop(rect, current.current.source) : null, notice: current.current.table ? '範囲を変更しました。「表を取り出す」で再認識できます。' : null }); }
      catch (error) { update({ error: getError(error) }); }
    },
    recognize,
    cancel() { stop(); update({ phase: current.current.table ? 'ready' : 'idle', progress: null, error: null, notice: '処理を中止しました。画像や表を変更して、もう一度試せます。' }); },
    setEngine(engine) { update({ engine }); },
    selectCell(row, column) { update({ selected: { row, column } }); },
    editCell(row, column, value) { modify(table => editCell(table, row, column, value), `${row}:${column}`); },
    addRow(index) { modify(table => addRow(table, index)); },
    deleteRow(index) { modify(table => deleteRow(table, index)); },
    addColumn(index) { modify(table => addColumn(table, index)); },
    deleteColumn(index) { modify(table => deleteColumn(table, index)); },
    undo() {
      const previous = history.current.past.pop();
      if (!previous || !current.current.table) return;
      history.current.future.push(current.current.table);
      grouping.current = { key: '', time: 0 };
      update({ table: previous, canUndo: history.current.past.length > 0, canRedo: true, selected: null, notice: 'ひとつ前に戻しました。' });
    },
    redo() {
      const next = history.current.future.pop();
      if (!next || !current.current.table) return;
      history.current.past.push(current.current.table);
      grouping.current = { key: '', time: 0 };
      update({ table: next, canUndo: true, canRedo: history.current.future.length > 0, selected: null, notice: 'やり直しました。' });
    },
    reset() { stop(); if (current.current.source) URL.revokeObjectURL(current.current.source.url); clearHistory(); update({ ...initialState, engine: current.current.engine }); },
    copyTable,
    downloadCSV,
    createManualTable() { stop(); clearHistory(); update({ table: createBlankTable(), selected: { row: 0, column: 0 }, phase: 'ready', error: null, progress: null, runtime: null, canUndo: false, canRedo: false, notice: '空の表を作りました。元画像を見ながらセルに入力できます。' }); },
  };
}

function getError(error: unknown): string {
  return error instanceof Error ? error.message : '処理に失敗しました。もう一度試してください。';
}
