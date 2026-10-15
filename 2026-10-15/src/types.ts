export interface Rect { x: number; y: number; width: number; height: number }
export interface SourceImage { name: string; url: string; width: number; height: number }
export interface OcrToken { text: string; confidence: number; box: Rect }
export interface TableCell { value: string; confidence: number; reviewed: boolean; box?: Rect }
export interface TableData { cells: TableCell[][]; rowEdges: number[]; columnEdges: number[]; method: 'ruled' | 'aligned' | 'manual'; warnings: string[] }
export interface GridHints { rowEdges: number[]; columnEdges: number[] }
export type EnginePreference = 'auto' | 'webgpu' | 'wasm';
export interface RuntimeInfo { detector: string; recognizer: string; elapsedMs: number }
export interface ProgressInfo { label: string; value: number | null }
export interface WorkspaceState {
  source: SourceImage | null;
  crop: Rect | null;
  table: TableData | null;
  selected: { row: number; column: number } | null;
  phase: 'idle' | 'loading-image' | 'loading-model' | 'recognizing' | 'ready' | 'error';
  progress: ProgressInfo | null;
  error: string | null;
  notice: string | null;
  engine: EnginePreference;
  runtime: RuntimeInfo | null;
  canUndo: boolean;
  canRedo: boolean;
}
export interface WorkspaceController {
  state: WorkspaceState;
  loadFile(file: File): Promise<void>;
  loadSample(): Promise<void>;
  setCrop(rect: Rect | null): void;
  recognize(): Promise<void>;
  cancel(): void;
  setEngine(engine: EnginePreference): void;
  selectCell(row: number, column: number): void;
  editCell(row: number, column: number, value: string): void;
  addRow(index: number): void;
  deleteRow(index: number): void;
  addColumn(index: number): void;
  deleteColumn(index: number): void;
  undo(): void;
  redo(): void;
  copyTable(): Promise<void>;
  downloadCSV(): void;
  reset(): void;
  createManualTable(): void;
}
