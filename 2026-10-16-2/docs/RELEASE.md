# 箱庭日本 v0.2 の公開

## Goal / Context / Constraints / Done when

- Goal：検証済みの箱庭日本v0.2を既存GitHub Pagesへ公開し、公開版の実操作と配信物を確認する。
- Context：2026-10-17、ユーザーが「公開しちゃっていいよ」と明示。ローカル版525ec96は44テスト・build・実ブラウザ確認を完了している。新指示により従来のローカル限定から公開工程へ進む。
- Constraints：対象は2026-10-16-2とそのカタログ登録のみ。調査正本、旧アプリ、他アプリと無関係な変更を保持。アプリやデータの内容は変更しない。既存のGitHub Pagesを使用し、新サービスや認証を追加しない。
- Done when：PR CI成功→main統合→main CI成功→Pages配備成功。公開URLの配信ファイルがその配備の成果物と一致し、公開版で主要操作・出典/欠測・小画面・consoleを確認できる。

## 配備方法

既存 `.github/workflows/deploy-pages.yml` をmainで手動実行する。変更アプリだけを検査・buildし、前回成功したPages成果物から他アプリを保持して完全なサイトを組み立てる。リリースタグの追加は必要ない。

予定URL： https://hayatok.github.io/100challenge/2026-10-16-2/

## 公開物の確認

独立した読み取り監査で、配信本体13ファイル＋照合用manifestのバイト一致を確認した。APIキー・認証情報・非公開個人資料は検出されず、研究用fixtures、原史料画像、PDF、ExcelはPagesへコピーされない。全15,728観測と259出典、55組のestat取得証拠の照合テストも成功している。GitHubのソースには再現検証のための政府公開統計のfixturesを含む。

## 実施結果

PR、CI、配備SHA、成果物の照合、公開版の操作結果は完了時にここへ追記する。ローカルの確認は [VERIFICATION.md](VERIFICATION.md) に記録済み。
