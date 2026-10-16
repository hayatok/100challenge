# 箱庭日本 v0.2 の公開

## Goal / Context / Constraints / Done when

- Goal：検証済みの箱庭日本v0.2を既存GitHub Pagesへ公開し、公開版の実操作と配信物を確認する。
- Context：2026-10-17、ユーザーが「公開しちゃっていいよ」と明示。ローカル版525ec96は44テスト・build・実ブラウザ確認を完了している。新指示により従来のローカル限定から公開工程へ進む。
- Constraints：対象は2026-10-16-2とそのカタログ登録のみ。調査正本、旧アプリ、他アプリと無関係な変更を保持。アプリやデータの内容は変更しない。既存のGitHub Pagesを使用し、新サービスや認証を追加しない。
- Done when：PR CI成功→main統合→main CI成功→Pages配備成功。公開URLの配信ファイルがその配備の成果物と一致し、公開版で主要操作・出典/欠測・小画面・consoleを確認できる。

## 配備方法

既存 `.github/workflows/deploy-pages.yml` をmainで手動実行する。変更アプリだけを検査・buildし、前回成功したPages成果物から他アプリを保持して完全なサイトを組み立てる。リリースタグの追加は必要ない。

公開URL： https://hayatok.github.io/100challenge/2026-10-16-2/

## 公開物の確認

独立した読み取り監査で、配信本体13ファイル＋照合用manifestのバイト一致を確認した。APIキー・認証情報・非公開個人資料は検出されず、研究用fixtures、原史料画像、PDF、ExcelはPagesへコピーされない。全15,728観測と259出典、55組のestat取得証拠の照合テストも成功している。GitHubのソースには再現検証のための政府公開統計のfixturesを含む。

## 実施結果

2026-10-17に公開を完了した。ローカルの確認は [VERIFICATION.md](VERIFICATION.md)、公開版の実操作は [public-browser.json](verification/v02/public-browser.json)、配信物の照合は [public-files.json](verification/v02/public-files.json) に記録した。

- 実装PR：[173](https://github.com/hayatok/100challenge/pull/173)、main統合SHA `1b87d0fc87a2785877aa0b8eb2ef34f5bbd5c6ba`。
- PR CI：[38935228550](https://github.com/hayatok/100challenge/actions/runs/38935228550)、main CI：[38935711531](https://github.com/hayatok/100challenge/actions/runs/38935711531) とも成功。
- Pages：[38935972964](https://github.com/hayatok/100challenge/actions/runs/38935972964)、build/deployとも成功。配備SHAは上記main統合SHAと一致。リリースタグは追加していない。
- 同runの成果物ID `12061875181`。本体13ファイル＋manifestの計14ファイルが全てHTTP 200で、成果物と公開版のバイト数・SHA-256が一致。カタログ登録も一致。
- 対象アプリの配信物にdocs/tests/fixtures/evidence/scriptsは含まれず、代表docs/fixture URLは404。
- 公開カタログからアプリを開き、1440×900と390×844で町・日常・次世代・出典・原欠測・資料庫・年代・全景・動きを減らす設定を操作。横overflowなし。
- 暮らし切替で統計/出生死亡/史実の文字列が不変、人物は変化。保存復元、資料閲覧中の停止と再開、自動進行、2026年10月の終端、最初からの再生、キーボードでの年代移動を確認。console warning/errorは0件。
- 年代不詳の記憶は全期間で読め、1943年の年別には自動割当されない。収録件数53表/184出来事/105生活史料/259出典/未解決94件を画面で確認。

公開確認の写真は [1440px](verification/v02/public-town-1440.jpg) と [390px](verification/v02/public-mobile-390.jpg)。実機スマートフォン、別ブラウザ、長時間のメモリ推移と利用者の継続観察の面白さは未確認。公開後の記録更新は文書だけで、上記配備のアプリ本体を変更しない。

## v0.3以降の品質改善

観察体験の改善は [Issue #175](https://github.com/hayatok/100challenge/issues/175) と [QUALITY_LOOP.md](QUALITY_LOOP.md) に記録する。v0.3の [PR #176](https://github.com/hayatok/100challenge/pull/176) は統合SHA `e29b2cb2d91f8a5437c3a5db67dbc96bcc98276f`、PR CI `38950944362`・main CI `38951080120`・Pages `38951196988` が成功した。公開版で1900年の原値・出典、範囲ドラッグ、点から町への移動、文化史検索、実際の交流、自動の年/季節進行を確認した。

その公開画面で交流時の過密を検出し、v0.3.1で会場の分散と会話表示、グラフのドラッグ中の反応を追加改善する。最新の配備SHA・CI/run・同run成果物との照合・公開の実操作結果は上記Issueへ追記する。前版の配備記録と当時の検証結果は保持する。
