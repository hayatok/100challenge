type HelpPanelProps = {
  open: boolean
  onClose: () => void
}

export default function HelpPanel({ open, onClose }: HelpPanelProps) {
  if (!open) return null
  return (
    <section className="help-panel" aria-labelledby="help-title">
      <div className="help-heading">
        <p className="machine-label">CLASSIFIED LIFE PROTOCOL</p>
        <h2 id="help-title">生命維持に関する極秘規定</h2>
        <p>極秘ですが、ボタンひとつで誰でも読めます。</p>
      </div>
      <div className="help-content">
        <section className="rule-section" aria-labelledby="survival-rule-title">
          <h3 id="survival-rule-title">生き残り規定</h3>
          <ul className="rule-list">
            <li><strong>誕生</strong><span>空き地の隣が、ちょうど3株</span></li>
            <li><strong>生存</strong><span>植物の隣が、2〜3株</span></li>
            <li><strong>枯死</strong><span>植物の隣が、0〜1株または4株以上</span></li>
          </ul>
          <p className="rule-note">庭の上下左右はつながっています。端だから安全、という制度はありません。</p>
        </section>

        <section className="rule-section" aria-labelledby="growth-rule-title">
          <h3 id="growth-rule-title">成長・開花規定</h3>
          <ol className="growth-list">
            <li><strong>1〜2世代</strong><span>芽</span></li>
            <li><strong>3〜5世代</strong><span>双葉</span></li>
            <li><strong>6世代以上</strong><span>草</span></li>
            <li><strong>周囲が8世代不変</strong><span>花</span></li>
          </ol>
          <p className="rule-note"><strong>花も無敵ではありません。</strong>安定した配置なら残り続けますが、周囲が変われば草へ戻るか、普通に枯れます。</p>
        </section>

        <section className="operation-notes" aria-labelledby="operation-title">
          <h3 id="operation-title">観測員の操作</h3>
          <ul>
            <li>庭を押す、または押したまま動かすと、種をまいたり取り除いたりできます。</li>
            <li>Spaceで停止・再開、Nで1世代進行。庭へfocusすると矢印キーとEnterでも操作できます。</li>
          </ul>
        </section>
      </div>
      <button className="help-close" type="button" onClick={onClose}>極秘規定を閉じる</button>
    </section>
  )
}
