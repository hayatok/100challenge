# 100challenge

毎日ひとつ、小さなWebアプリを作るチャレンジです。アプリ固有のコードと依存関係は制作開始日ごとのフォルダへ置きます。

## Apps

| Date | App | Description |
| --- | --- | --- |
| 2026-09-01 | [やってる感](./2026-09-01/) | 具体的なことを言わない進捗報告ジェネレーター |
| 2026-09-02 | [いのちの庭](./2026-09-02/) | 過剰な生命観測装置で見守る8bitライフゲーム |

開発状況は [GitHub Project](https://github.com/users/hayatok/projects/3) と [Issues](https://github.com/hayatok/100challenge/issues) で管理します。

## Local showcase

`apps.json` に登録した各アプリをビルドし、GitHub Pagesと同じディレクトリ構成でローカル確認できます。

```bash
npm run build:site
npm run preview:site
```

ショーケースは `http://127.0.0.1:4173/`、各アプリは `http://127.0.0.1:4173/YYYY-MM-DD/` または `http://127.0.0.1:4173/YYYY-MM-DD-N/` で開きます。

## Publish

通常のpushではGitHub Pagesを更新しません。公開するコミットを`main`へ反映した後、`release-*`形式のタグをpushすると、全アプリの依存関係をインストールし、テスト・lint・ビルドを通過した成果物だけを公開します。

```bash
git tag release-YYYY-MM-DD
git push origin release-YYYY-MM-DD
```

同じ日に複数回公開する場合は、`release-YYYY-MM-DD-2`のように末尾へ通し番号を付けます。GitHubのActions画面から手動実行することもできます。
