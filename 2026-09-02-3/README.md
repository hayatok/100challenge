# 数字がわかるまで

本当に動いているMNIST数字認識モデルの、考える途中と学ぶ瞬間を観察するブラウザアプリです。

## What is real

- `784 → 16 → 10`の全結合ニューラルネットワークをTensorFlow.jsで実行
- `Conv 8 → Pool → Conv 16 → Pool → Dense 10`のCNNを独立した観察室で実行
- MLP / CNNの全体経路と現在の計算位置を示すライブ・ネットワーク模式図
- CNNはThree.jsで入力面、特徴マップ群、接続、出力ノードを1つの3D空間へ描画
- 入力、隠れ層の活性値、logit、Softmax確率を実際の順伝播から取得
- Guided trainingではcross entropy loss、全パラメータの勾配、SGD更新量を実計算
- 計算後に不変の`ComputationTrace`を作り、その値だけを段階再生
- 再生、一時停止、巻き戻しでモデルを再計算・再更新しない

## Modes

- **1件を学ぶ**: 未学習モデルの予測から、batch size 1の学習と更新後の再推論までを追う
- **推論を見る**: フルMNISTで事前学習したモデルの順伝播を観察する
- **CNN 畳み込み**: 特徴マップ、局所積和、Pooling、受容野、数字別の証拠、遮蔽再推論を実値で観察する
- **CNN 1件を学ぶ**: 未学習CNNで1件のcross entropy、勾配、SGD更新、更新前後の推論を追う
- **CNN まとめて学ぶ**: 10・50・100件を連続学習し、test 1,000件の精度とloss推移を実測する
- **まとめて学ぶ**: ブラウザ内で500件を学習し、batch lossとtest subset正答率を実測する
- **自分で書く**: 手描きを28×28へ前処理し、実際にモデルへ渡す入力と予測を見る

## Data and model

- Source: Keras MNIST `mnist.npz`
- Dataset license: CC BY-SA 3.0
- Bundled training subset: 5,000件（各数字500件）
- Bundled test subset: 1,000件（各数字100件）
- Pretrained model: train 60,000件、12 epochs、SGD 0.05
- Pretrained test accuracy: 94.02% / 10,000件
- CNN: subset 5,000件、12 epochs、Adam 0.003
- CNN test subset accuracy: 97.8% / 1,000件
- Selection and initialization seed: `20260902`

取得元、チェックサム、split、モデル条件は`public/data/manifest.json`、帰属は`public/data/LICENSE-MNIST.md`を参照してください。

## Development

```bash
npm install
npm run dev
npm run check
```

MNISTデータと学習済み重みを再生成する場合は、Python 3とNumPyを用意して実行します。

```bash
python3 -m pip install -r scripts/requirements.txt
npm run prepare:data
npm run prepare:cnn
```

`prepare:cnn`は既存のTensorFlow.js依存だけで重みを再生成します。Node.js上の純JavaScript実行なので、完了まで時間がかかります。

## Validation routes

- 通常: `/`
- データ読み込み失敗: `/?data-error=1`
- モデル読み込み失敗: `/?model-error=1`

## Documents

- [承認済み仕様](./docs/SPEC.md)
