# 素材と編集元

- キャラクター・車・建物・敵・木・コア: このゲーム用に作成したオリジナルの3D形状。Blender編集元は `source/mogu.blend` と `source/miniatures.blend`、Godot向けは `game/assets/models/*.glb`。丸いシルエット、珊瑚色の怪獣、クリームの腹、青緑の街を共通方向にした。
- キャラクターアニメーション: Godot AnimationPlayerの部位トラック。9種類とRESET。歩行と走行の足運び、顎の開閉、尻尾、停止時の重心変化を個別に記述。
- アスファルト: 内蔵画像生成ツールで制作した `game/assets/textures/miniature-asphalt.png`。モデル名と品質値はツールから指定・確認できない。GPT Image 2.5/max使用という証明はしていない。ユーザーが内蔵ツールでの続行を承認済み。
- 音楽と効果音: `scripts/make_audio.py` によるオリジナル合成音。112 BPMのマレット・ベースと、捕食・衝突・警告・成長等の効果音。既成の録音素材は使っていない。
- 日本語フォント: Noto Sans CJK JP Medium。SIL Open Font License。配布ライセンスは `game/assets/fonts/LICENSE.txt` に同梱。

GLB上の各パーツとマテリアルを編集できるため、画像の再生成を必要とせず、輪郭・色・演技を調整できる。Blender原型生成スクリプトの再実行は、後から行ったモデル編集を上書きする。編集前に版を保存すること。
