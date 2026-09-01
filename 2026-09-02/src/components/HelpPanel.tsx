type HelpPanelProps = {
  open: boolean
  onClose: () => void
}

export default function HelpPanel({ open, onClose }: HelpPanelProps) {
  if (!open) return null
  return (
    <section className="help-panel" aria-labelledby="help-title">
      <div>
        <p className="machine-label">OPERATING NOTES</p>
        <h2 id="help-title">見守りかた</h2>
      </div>
      <ul>
        <li>庭を押すと、種をまいたり取り除いたりできます。</li>
        <li>押したまま動かすと、まとめて種をまけます。</li>
        <li>Spaceで観測を停止・再開、Nで生命を1回だけ進めます。</li>
        <li>庭へfocusすると、矢印キーとEnterでも操作できます。</li>
      </ul>
      <button type="button" onClick={onClose}>説明を閉じる</button>
    </section>
  )
}
