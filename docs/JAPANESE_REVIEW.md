# 日本語の推敲

画面文言、README、仕様書、PR説明などで、今回作成・変更した日本語を対象にする。対象の文章を読み、何が読みにくいかを確かめてから直す。自然に読める文章は残す。

## 手順

1. 利用できる `yomiyasu` スキルの `SKILL.md` を読む。文書の種類に応じた参照資料も確認する。
2. 書き直す前の原文を別ファイルへ保存し、`yomiyasu_lint.py` を実行する。新規作成では、依頼や仕様などの資料を用意する。
3. 動作主と対象、条件、否定、数値、名称、確度を保って推敲する。操作手順や規則の箇条書き、コード、URL、引用は役割を確かめて残す。
4. `yomiyasu_check.py run` を実行し、候補と全文差分を読む。新規作成では資料と照合する。候補を減らすためだけに書き換えず、修正回数はスキルに従う。
5. 最終稿を実ファイルへ反映し、`verify` でハッシュが記録と合ったことを確認する。その後に文章を変えたら、変更後の文章を検査して照合し直す。
6. 対象、主な変更、採用しなかった候補の理由、実行した検査と未実施の検査を報告する。画面文言は実画面でも確認し、AI Slopレビューへ渡す。

## コマンド例

`YOMIYASU_SKILL_DIR` に、利用するスキルのフォルダを指定する。`work` は作業用のフォルダで、原文、資料、最終稿、検査記録を置く。文書の種類や立場は対象に合わせて選ぶ。

```bash
python3 "$YOMIYASU_SKILL_DIR/scripts/yomiyasu_lint.py" work/original.md --doc-type manual
python3 "$YOMIYASU_SKILL_DIR/scripts/yomiyasu_check.py" run \
  --source work/original.md --final work/final.md \
  --stance 説明 --doc-type manual --fact-gaps --state-dir work/records
```

新規作成では `--source` を外し、`--material work/material.md` を渡す。検査した最終稿を実ファイルへ反映した後、次のコマンドを実行する。

```bash
python3 "$YOMIYASU_SKILL_DIR/scripts/yomiyasu_check.py" verify \
  --final path/to/actual.md --state-dir work/records
```

記録には原文や最終稿が含まれる。保管先を明示し、個人情報や未公開情報を含む記録を誤ってコミットしない。アプリ固有の実施結果は、日付フォルダの検証記録に置く。

`run` の実行やハッシュの一致は、意味の保持や読みやすさの合格判定ではない。候補ゼロでも文章を読み、実装・仕様と一致するかを確認する。スキルやPythonを利用できない場合は、理由と目視で確認した範囲を報告する。
