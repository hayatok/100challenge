# 数字がわかるまで — 仕様書 v1.0

- Status: Approved for implementation
- App ID: `2026-09-02-3`
- Last updated: 2026-09-02

## 1. Task definition

### Goal

MNISTの手書き数字を認識する小さなニューラルネットワークをブラウザ内で実際に動かし、入力、順伝播、予測、誤差、逆伝播、重み更新の関係を、モデルが計算した実値に基づくアニメーションで理解できる学習アプリを作る。

### Context

- 共通デザイン方針: `../../docs/DESIGN.md`
- フロントエンド方針: `../../docs/FRONTEND.md`
- デイリーアプリの共通スタイル: `../../docs/DAILY_APP_STYLE.md`
- 題材: MNISTによる0〜9の手書き数字分類
- 実行環境: desktop / mobileのWebブラウザ
- 技術候補: React、TypeScript、CanvasまたはSVG、TensorFlow.js Core API
- 最重要のプロダクト判断: アニメーション用に作った架空値ではなく、実際のモデルが算出した入力、活性値、確率、損失、勾配、更新前後の重みを表示する

### Constraints

- ログイン、バックエンド、外部推論API、生成モデルを使わない
- 学習、推論、可視化に必要なデータとモデルは静的ファイルとして配信し、実行時は端末内で処理する
- 可視化のためにモデルの計算結果を改変しない。丸め、正規化、上位接続への絞り込みは表示処理として明示する
- アニメーションの進行時間とモデルの計算時間を混同しない
- 学習データとテストデータを混ぜない
- 「確信度」を正解確率として扱わない。表示するのはモデルが各クラスへ割り当てたSoftmax確率である
- 784個の入力と全結合線を同時に描かず、情報量を集約しながら、選択した値の由来を追跡できるようにする
- 学習の説明を優先し、Version 1ではCNN、畳み込み、プーリングを扱わない
- `prefers-reduced-motion`、キーボード操作、色覚に依存しない状態表現を用意する
- モデルまたはデータの読み込みに失敗した場合、架空のデモへフォールバックしない

### Done when

- MNISTサンプルまたはユーザーが描いた数字に対し、ブラウザ内の実モデルが推論する
- 入力値、隠れ層の活性値、出力確率が実際の順伝播結果と一致する
- MNISTサンプル1件を使った学習で、実際の損失、勾配、更新量を段階的に確認できる
- まとめ学習により、同じブラウザセッション内でモデルの損失とテスト正答率が変化する
- 学習前後で同じ入力を推論し、出力の変化を比較できる
- 可視化した数値がモデル内部値と一致することを自動テストで証明できる
- loading、ready、playing、paused、training、complete、data error、model error、unsupported、reduced motionを確認できる
- 375px、768px、1024px、1440pxで主要操作と中心図が成立する
- unit test、integration test、lint、typecheck、buildが通る
- 実ブラウザで学習、推論、手描き入力、エラー、モバイル操作を確認する

## 2. Product concept

### Product name

**数字がわかるまで**

### Tagline

**ニューラルネットは、いつ「3」を3だと思うようになるのか。**

### One-line description

本当に動いている数字認識モデルの、考える途中と学ぶ瞬間を観察するアプリ。

### Target user

- ニューラルネットワークという言葉は知っているが、推論と学習の違いを説明できない人
- 数式だけでは全体像をつかみにくい初学者
- 実際の値を触りながら、活性化、確率、損失、勾配、重み更新の関係を確認したい開発者

### Primary experience

ユーザーはMNISTの数字を1枚選び、実モデルの順伝播を段階再生する。モデルの予測と正解を比較した後、同じサンプルを1件学習させると、誤差が逆向きに伝わり、どの重みがどれだけ変わったかを確認できる。最後にもう一度推論し、1回の学習で判断がどう変わったかを見る。

### Experience principles

1. **実計算が主役**: 動きは、モデルから取得した値を読むために存在する。
2. **一周を理解する**: 入力から重み更新までを、別々の豆知識ではなく1本の流れとして見せる。
3. **詳細は選んで見る**: 全接続を描かず、気になるニューロンや数字を選ぶと根拠へ降りられる。
4. **速さと理解を分ける**: 実計算時間と、説明用の再生時間を別々に表示する。
5. **モデルの限界を隠さない**: 間違いや曖昧な手描き入力も、そのまま観察対象にする。
6. **用語を言い換えてから示す**: 平易な説明を先に置き、正式名称と式を補助表示する。

## 3. Learning objectives

体験後、ユーザーが次を説明できることを目標とする。

1. 画像はモデルへ「絵」ではなく784個の数値として渡される
2. 重み付き和と活性化関数によって次の層の値が決まる
3. 出力は断定ではなく、0〜9へ配分された確率である
4. 学習では予測と正解の差を損失として測る
5. 逆伝播は各パラメータが損失へ与えた影響を勾配として求める処理である
6. 重みを一度で正解へ置き換えるのではなく、勾配と学習率に基づいて少しずつ更新する
7. 正答率は訓練に使っていないテストデータで測る必要がある

Version 1では、次の理解を目標にしない。

- CNNのフィルターと特徴マップ
- 畳み込み、プーリング、データ拡張
- Adamのモーメント推定
- 大規模言語モデルや生成モデルの構造
- ニューロンが人間と同じ概念を理解しているという説明

## 4. Scope

### Version 1に含める

- MNISTサンプルの選択
- 28×28入力テンソルの表示
- 全結合ネットワーク `784 → 16 → 10`
- 学習済みモデルによる推論
- ユーザーがブラウザ内で初期化する学習用モデル
- 1件学習の詳細トレース
- まとめ学習と損失・テスト正答率の推移
- 手描き数字の前処理結果と推論
- 選択ニューロンの寄与上位接続
- 学習前後の予測比較
- 一時停止、前後ステップ、最初から再生、最後まで進める、再生速度変更
- 用語説明と式の表示切り替え
- Guided training直前の状態へ戻す `学習前へ戻す`
- モデルのリセット
- データ、モデル、端末性能に関するエラー表示

### Version 1に含めない

- CNNまたは複数のモデル構造の比較
- モデル構造、隠れ層数、ニューロン数の編集
- ハイパーパラメータ探索
- ユーザーによる任意データセットのアップロード
- 学習済みモデルのダウンロード、共有、同期
- フルMNIST 60,000件をブラウザで最初から学習する体験
- 教師なし学習、生成、強化学習
- 音声、BGM、効果音
- 正答率ランキング、スコア、実績

## 5. Representation integrity

### 5.1 Non-negotiable rule

画面上の意味を持つすべての動きは、次のいずれかをデータソースに持つ。

- 入力テンソル
- パラメータ
- 中間活性値
- logitsまたはSoftmax確率
- 損失
- 勾配
- 更新前後のパラメータ差分
- モデルが完了した処理の状態

装飾の粒子、ランダムな発火、値と無関係な線の明滅を、計算の表現として使わない。

### 5.2 Computation and playback

- 推論または学習操作を開始すると、モデルは先に計算を完了する
- 計算結果を不変の `ComputationTrace` として保存し、そのトレースをアニメーション再生する
- UIには `計算 18ms / 1.5秒で再生中` のように、計算時間と再生時間を分けて表示する
- 再生速度、一時停止、巻き戻しはトレースの表示位置だけを変更し、モデルを再計算しない
- 学習操作1回につき、重み更新は1回だけ適用する
- 再生を巻き戻しても学習を取り消さず、同じ更新を再適用しない
- 学習を取り消す操作は、トレース操作と分離した `学習前へ戻す` として明示する
- 新しい推論または学習を開始するときは、現在の再生を終了または明示的に中断する

### 5.3 Aggregation and display transforms

- 隠れ層の16ニューロンと出力10クラスは全件表示する
- 入力層は784ノードの円ではなく、28×28ピクセルグリッドとして表示する
- 接続線は通常時に全件表示しない
- 選択したニューロンについて、寄与の絶対値が大きい上位10件を表示する
- 順伝播の寄与は `前層の活性値 × 重み` と定義する。重み単体を寄与と呼ばない
- 逆伝播では `|∂loss / ∂weight|` が大きい上位10件を表示する
- 線幅を画面内の最大値へ正規化する場合は、凡例に `この層内で相対表示` と記載する
- 数値は表示時だけ丸め、計算には丸め前のfloat32値を使う
- 表示範囲へ収めるためクリップした場合は、クリップされた値と上限を詳細表示で確認できるようにする

## 6. Dataset specification

### 6.1 Source

MNISTは次の構成を持つ。

- 訓練データ: 60,000件
- テストデータ: 10,000件
- 画像: 28×28、8bitグレースケール
- ラベル: 0〜9
- ライセンス: Creative Commons Attribution-Share Alike 3.0

実装時はデータ同梱物に次を記録する。

- 取得元URL
- 取得日
- 元ファイル名とチェックサム
- ライセンスと帰属表示
- 変換スクリプト
- subsetの選択規則、乱数seed、件数、クラス別件数

### 6.2 Bundled data

静的配信サイズと学習時間を抑えるため、Version 1では次を同梱する。

| Split | Count | Usage |
| --- | ---: | --- |
| Guided samples | 100 | 初期表示と1件学習。各数字10件 |
| Browser training subset | 5,000 | まとめ学習。各数字500件 |
| Browser test subset | 1,000 | 正答率評価。各数字100件 |

- subsetは元のtrain/test splitを維持する
- 各split内の選択は固定seedによる層化抽出とする
- Guided samplesはBrowser training subsetに含めてよいが、test subsetには含めない
- test subsetは評価だけに使い、勾配計算へ渡さない
- UIには `MNIST訓練データの一部 5,000件` と表示し、フルデータで学習しているように見せない

### 6.3 Input preprocessing

MNISTサンプルはuint8の画素値を `x = pixel / 255` により0〜1へ正規化し、行優先で784要素へ平坦化する。

手描き入力は次の順番で変換する。

1. 280×280の描画Canvasをグレースケール化する
2. 描画の外接矩形を求める
3. アスペクト比を維持して20×20以内へ縮小する
4. 28×28の中央へ配置し、画素重心が中央へ近づくよう平行移動する
5. 0〜1へ正規化する
6. 実際にモデルへ渡す28×28画像を、元の手描きCanvasと並べて表示する

空白、画素数が閾値未満、または外接矩形を作れない入力は推論せず、追記を案内する。前処理は推論用モデルの訓練条件と一致させる。

## 7. Model specification

### 7.1 Architecture

| Layer | Shape | Operation |
| --- | --- | --- |
| Input | `[batch, 784]` | 0〜1の画素値 |
| Dense 1 | `[784, 16]` + bias `[16]` | `z1 = xW1 + b1` |
| Activation | `[batch, 16]` | `a1 = ReLU(z1)` |
| Dense 2 | `[16, 10]` + bias `[10]` | `logits = a1W2 + b2` |
| Output | `[batch, 10]` | `p = Softmax(logits)` |

パラメータ数は次のとおり。

- `W1`: 12,544
- `b1`: 16
- `W2`: 160
- `b2`: 10
- 合計: 12,730

### 7.2 Loss and prediction

- 正解ラベルは10クラスのone-hotベクトルへ変換する
- 損失はSoftmax cross entropyを使う
- 単一サンプルの説明では `loss = -log(p[正解ラベル])` を表示する
- 予測クラスは最大logitと同じ位置のクラスとする
- 出力棒はSoftmax確率を表示し、合計が丸め前で1になる
- `最大確率` はモデルの確信の強さとしてのみ扱い、正解の保証とは説明しない

### 7.3 Training

- optimizer: stochastic gradient descent
- 初期learning rate: `0.05`
- Guided training: batch size `1`
- Bulk training: batch size `32`
- 初期化: Glorot uniform、固定seed
- シャッフル: epochごとに固定seed系列で決定可能にする
- 重み更新: `weight_after = weight_before - learning_rate × gradient`
- 学習率はVersion 1ではユーザー編集不可とし、詳細表示で確認できる

数値は実装前の初期値であり、学習が発散する、または体験時間内に変化を観測できない場合は、検証結果と変更理由を仕様書へ追記して調整する。Adamは仕組みの説明が増えるためVersion 1では使わない。

### 7.4 Two model instances

#### 学習済みモデル

- 同じ `784 → 16 → 10` 構造をフルMNIST訓練データで事前学習し、重みを静的ファイルとして同梱する
- 初回の推論モードと手描き入力で使う
- 学習コード、訓練条件、評価結果、生成コミットをmanifestへ記録する
- test splitに対する正答率をモデル情報へ表示する

#### 学習観察モデル

- ブラウザ内で固定seedから新規初期化する
- Guided trainingとBulk trainingで実際に更新する
- Browser training subsetだけで学習し、Browser test subsetで評価する
- リセットすると初期seed、重み、学習回数、指標を初期状態へ戻す

2つのモデルを同じものに見せない。画面上部へ常に `学習済みモデル` または `いま学習中のモデル` を表示する。

## 8. Computation trace

### 8.1 Trace contract

各推論・学習操作は次の情報を持つ不変オブジェクトを生成する。

```ts
type ComputationTrace = {
  traceId: string
  kind: 'inference' | 'guided-training'
  modelId: 'pretrained' | 'learning'
  modelRevisionBefore: number
  modelRevisionAfter: number
  sampleId: string | 'user-drawn'
  label: number | null
  predictedClassBefore: number
  predictedClassAfter: number | null
  computeDurationMs: number
  input: Float32Array
  parametersBefore: ParameterSnapshot
  forwardBefore: ForwardSnapshot
  lossBefore: number | null
  gradients: GradientSnapshot | null
  updates: ParameterDeltaSnapshot | null
  parametersAfter: ParameterSnapshot | null
  forwardAfter: ForwardSnapshot | null
}
```

`ForwardSnapshot` は少なくとも `z1[16]`、`a1[16]`、`logits[10]`、`probabilities[10]` を持つ。学習トレースは全パラメータの勾配と更新量を保持する。

### 8.2 Trace lifecycle

1. 現在のモデルrevisionを取得する
2. 更新前パラメータをsnapshotする
3. 順伝播、損失、勾配、更新後パラメータを計算する
4. Tensor値を非同期にTypedArrayへコピーする
5. 中間Tensorを破棄する
6. モデル更新を1回だけcommitする
7. `ComputationTrace` をUIへ渡す
8. UIはtraceだけを参照してアニメーションする

trace作成後にモデルが別操作で更新された場合も、再生中のtrace表示は変化させない。新しい操作は再生終了までdisabledにするか、ユーザーの中断確認後に開始する。

### 8.3 Playback phases

#### Inference

1. `input` — 28×28の画素値を表示
2. `hidden-sum` — `z1`へ寄与が集まる
3. `relu` — 負の値が0になり、`a1`が確定する
4. `logits` — 10クラスの採点値を表示
5. `softmax` — 採点値を確率へ変換する
6. `prediction` — 最大値のクラスをモデルの回答として示す

#### Guided training

推論6段階に続けて次を再生する。

7. `compare` — 正解ラベルと予測を比較する
8. `loss` — cross entropy lossを表示する
9. `output-gradient` — 出力側の勾配を表示する
10. `hidden-gradient` — 隠れ層へ勾配が戻る
11. `parameter-update` — 上位更新量と更新前後の値を表示する
12. `after-inference` — 更新後の同じ入力に対する確率を表示する

各phaseには、短い平易な説明、正式名称、実値を用意する。式は初期状態では折りたたみ、選択時に現在の値を代入した形で表示する。

## 9. Visualization semantics

### 9.1 Input

- 28×28グリッドの明度は実際の0〜1入力値へ対応する
- 選択したピクセルに `row`、`column`、`raw uint8`、`normalized value` を表示する
- 手描き入力では元画像と前処理後テンソルを区別する

### 9.2 Hidden layer

- 16ニューロンを固定位置に並べる
- 円の塗り量または内部バーをReLU後の活性値へ対応させる
- 負の `z1` は打ち消し線または閉じたゲートで示し、色だけに頼らない
- 選択時に `z1`、`a1`、bias、寄与上位入力を表示する
- ニューロンへ「曲線を見つけた」など、人間的な概念名を自動付与しない

### 9.3 Output

- 0〜9を同一スケールの横棒で常時表示する
- phaseに応じてlogitまたはSoftmax確率を表示し、混在させない
- 予測クラス、正解ラベル、最大確率を、色に加えて文言と形で区別する
- 間違いは故障ではなく、モデルの現在の出力として扱う

### 9.4 Connections

- 正の値と負の値を異なる色と線種で表す
- 線幅は絶対値に対応する
- 順伝播時は寄与、逆伝播時は勾配、更新時は差分だけを表示する
- 同じ線の意味をphase中に混在させない
- 凡例へ現在の線の意味、単位、相対スケールを表示する
- 値が0または表示閾値未満の接続は省略し、省略件数を表示する

### 9.5 Metrics

Bulk training中は次だけを表示する。

- 処理済み訓練サンプル数
- 現在epoch
- 直近batch loss
- test subset正答率

lossとaccuracyは別軸または別図にし、同じ単位に見せない。accuracyはtest subset 1,000件に対する評価であることを常に併記する。更新中のグラフ値は実測値だけを追加し、補間した架空の点を作らない。

## 10. Interaction specification

### 10.1 Main modes

| Mode | Primary action | Model |
| --- | --- | --- |
| 推論を見る | `この数字を読ませる` | 学習済みモデル |
| 1件を学ぶ | `この1件を学習する` | 学習観察モデル |
| まとめて学ぶ | `500件学習する` | 学習観察モデル |
| 自分で書く | `書いた数字を読ませる` | 学習済み / 学習観察モデルを選択 |

モード切り替え時は、入力と現在のモデルを保持できる場合は保持する。未完了の学習トレースがある場合は、切り替え前に再生を終了する。

### 10.2 Playback controls

| Control | Behavior | Keyboard |
| --- | --- | --- |
| 再生 / 一時停止 | traceの自動再生を切り替える | `Space` |
| 1つ戻る | 前phaseの先頭へ移動する | `ArrowLeft` |
| 1つ進む | 次phaseの先頭へ移動する | `ArrowRight` |
| 最初から見る | phase 1へ戻る。再計算しない | `Home` |
| 最後まで進める | 最終phaseを表示する | `End` |
| 再生速度 | `0.5x / 1x / 2x` | なし |

テキスト入力中、Canvas描画中、select操作中はグローバルショートカットを発火させない。再生位置を戻してもモデルrevisionが変わらないことを画面上で示す。

### 10.3 Sample selection

- 初期サンプルは固定し、初回体験を再現可能にする
- `別の数字` で各クラスから均等に選ぶ
- 数字ラベルで絞り込める
- サンプルにはtrainまたはtestの区分を表示する
- testサンプルをGuided trainingへ使わせない

### 10.4 Learning actions

- `この1件を学習する` は現在選択中のtrainサンプルだけでbatch size 1の更新を1回行う
- 更新前後の予測と損失を同じtraceに保存する
- `500件学習する` はBrowser training subsetから次の500件をbatch size 32で学習する
- Bulk training中は詳細な信号アニメーションを再生せず、実測の進捗と指標だけを更新する
- Bulk training完了後、任意の1件を選び現在のモデルで詳細推論できる
- 学習中の停止要求は現在batchの完了後に受け付ける
- 停止時に完了済みbatchを巻き戻さない
- リセットには確認操作を設け、学習観察モデルだけを初期化する

## 11. Screen specification

### 11.1 Main screen

#### User goal

数字が入力から予測へ変わる流れを追い、学習によって判断が変化する理由を見る。

#### Information hierarchy

1. 28×28入力、隠れ層、0〜9出力からなる中心図
2. 現在のphaseと1文説明
3. 再生 / 1ステップ操作
4. 現在のモデルとサンプル区分
5. 選択した値の詳細、式、学習指標

#### Desktop: 1024px以上

```text
┌ 数字がわかるまで ─ いま学習中のモデル ─ revision 0042 ┐
│ [推論を見る] [1件を学ぶ] [まとめて学ぶ] [自分で書く] │
├───────────────┬─────────────────┬──────────────┤
│ 28×28 INPUT   │ HIDDEN 16       │ OUTPUT 0〜9  │
│               │                 │ 0 ███ 0.18   │
│   MNIST画像   │  ● ● ● ●       │ 1 █ 0.03     │
│   または      │  ● ● ● ●       │ …            │
│   描画結果    │  ● ● ● ●       │ 7 █████ 0.61 │
│               │  ● ● ● ●       │ …            │
├───────────────┴─────────────────┴──────────────┤
│ STEP 4/6 Softmax — 10個の採点値を確率へ変換しました │
│ [最初] [戻る] [再生] [進む] [最後]      速度 [1x] │
├───────────────────────────────────────────────┤
│ 選択中の値 / 式 / 相対表示の凡例                     │
└───────────────────────────────────────────────┘
```

- 中心図を横3列で配置し、入力から出力への左→右の流れを保つ
- 接続線は中心図の背面に描かず、選択した接続だけを前面に表示する
- phase説明と再生操作を中心図の直下へ固定する
- 詳細領域は選択時だけ展開し、初期画面をダッシュボード化しない

#### Tablet: 768〜1023px

- 入力、隠れ層、出力の横並びを維持する
- 28×28画像を縮小し、接続の数値詳細は下段へ移す
- モード操作は2行まで許可する
- 中心図と再生操作を初期viewport内に優先する

#### Mobile: 375〜767px

- 中心図は横スクロールさせず、`入力 → 隠れ層 → 出力` を縦に並べる
- phaseごとに主役の層を大きくし、他の層は小さな要約として残す
- 出力10本は省略せず表示する
- 再生操作は画面下部へ固定せず、中心図の直後に置く
- `戻る / 再生 / 進む` を主操作とし、最初・最後・速度は補助列へ置く
- 選択詳細は中心図の下で展開する
- 44×44px以上のタップ領域を確保する
- 375×667で現在phase、主役の層、戻る・再生・進むが初期viewport内に見えることを優先する

### 11.2 Guided training sequence

最初の体験は次の順番で案内する。

1. 固定されたtrainサンプルの「3」を表示する
2. `まず予想を見る` で学習観察モデルの推論を再生する
3. 正解と現在の予測を比較する
4. `この1件を学習する` で実際に1回更新する
5. 勾配と更新量を段階再生する
6. 更新前後の0〜9確率を比較する
7. `500件まとめて学ぶ` または `別の数字で試す` を提示する

導入説明だけの別ページは作らず、実モデルが見える画面上で始める。

## 12. Visual direction

### Metaphor

**理科室の透明な計算機**。ブラックボックスを魔法として演出せず、太い配線、観察窓、数値ラベルを持つ実験装置として見せる。

今回は既存作の官僚ジョークやゲーム画面から意図的に離れ、可視化の正確さを主役にする。共通スタイルの太い輪郭、フラットな色、硬い影、短い反応は保つが、笑いを必須にせず、驚きは実際の値が動くことから生む。

### Palette

| Role | Color | Usage |
| --- | --- | --- |
| Paper | `#F3EFE4` | 全体背景 |
| Ink | `#182126` | 文字、輪郭、軸 |
| Forward | `#167A84` | 正方向の信号、正の寄与 |
| Negative | `#B33A5B` | 負の寄与、抑制 |
| Update | `#D99A16` | 勾配、重み更新、主操作 |

実装時にWCAG AAを確認する。正負、正解、不正解、選択状態は色だけでなく、実線 / 破線、`+ / −`、ラベル、形を併用する。

### Shape and typography

- 中心図は1つの連続した観察面として扱い、層ごとにカード化しない
- 主要な輪郭は2〜3px、影は2〜4pxの硬いオフセットに限定する
- 数値、式、revision、shapeは等幅書体を使う
- 説明文は読みやすい日本語システムフォントを使う
- 角丸、発光、グラデーション、ガラス表現を使わない
- ニューロンを脳、顔、キャラクターとして擬人化しない

### Motion

- phase間の移動は200〜500ms
- 活性値の変化は、値に対応する塗り量またはバーの長さの変化として示す
- 接続線の移動速度を値の大きさとして使わない。値は線幅、符号、数値で示す
- 逆伝播は方向の違いを短い移動で示せるが、勾配値と無関係な連続パルスを流さない
- 重み更新はbefore / delta / afterを同時に読める形で300〜600ms以内に切り替える
- 常時動く背景、点滅、揺れ、粒子を使わない
- `prefers-reduced-motion: reduce` では補間移動を止め、phaseごとの即時切り替えと数値差分だけを表示する

## 13. Required states

| State | Expected UI | Available action |
| --- | --- | --- |
| Initial loading | 中心図の領域を確保し、データとモデルの個別進捗を表示 | 待機 |
| Ready | 固定サンプル、モデル名、開始操作を表示 | 推論または学習開始 |
| Computing | `モデルが計算中` と実経過時間を表示。重複操作を防止 | 中断不可、短時間で完了 |
| Playing | 現在phaseとtrace由来の値を表示 | 一時停止、前後移動 |
| Paused | 同じ値を保持 | 再生、前後移動 |
| Bulk training | batch境界ごとの実進捗と指標 | batch完了後に停止 |
| Complete | 最終出力と次の操作 | 再生、別入力、学習 |
| Empty drawing | 推論せず、線を追加するよう案内 | 描画 |
| Dataset error | 失敗したデータ名と再試行を表示 | 再試行 |
| Model error | 推論結果を作らず、再読み込みを表示 | 再試行 |
| Unsupported backend | CPU backendで再試行し、速度低下を説明 | 続行または再試行 |
| Numeric error | NaN / Infinityを検出し、学習を停止。最後の正常revisionを保持 | リセット |
| Reduced motion | 即時phase切り替え。情報量は通常時と同じ | 全操作 |
| Hidden tab | 自動再生を停止し、Bulk trainingは現在batch完了後に一時停止する。未処理時間を早送りしない | 復帰後に再開 |

データまたはモデルが使えないときは、ランダム値で「それらしい」可視化を継続しない。

## 14. Technical architecture

### 14.1 Modules

| Module | Responsibility |
| --- | --- |
| `data` | MNIST manifest、split、デコード、正規化、subset検証 |
| `model` | パラメータ、順伝播、損失、勾配、更新、評価 |
| `trace` | Tensorから不変snapshotを作り、revisionを管理する |
| `playback` | phase、再生位置、速度、一時停止。モデルを変更しない |
| `visualization` | traceをCanvas / SVGへ写像する |
| `drawing` | 手描き入力、前処理、空判定 |
| `training-worker` | Bulk trainingと評価。進捗をbatch境界で通知する |

モデル計算と描画を分離する。描画コードから乱数、推論、勾配計算、パラメータ更新を呼ばない。

### 14.2 TensorFlow.js policy

- Core APIと`tf.variableGrads`またはOptimizerの`computeGradients` / `applyGradients`を使い、勾配をtraceへ保存できる構成を選ぶ
- 中間Tensorは`tf.tidy()`と明示的な`dispose()`で管理する。`tf.tidy()`へasync関数を渡さず、traceへ残すTensorだけを`tf.keep()`または戻り値で保持する
- UIへ渡す値は保持したTensorから`data()`で非同期取得し、TypedArrayへコピーした後にTensorを破棄する。同期的な`dataSync()`をアニメーションループ内で使わない
- 初期backendは利用可能性を検証して選ぶ
- backendが異なっても同じ入力と重みで予測クラスが一致することを確認する
- 初回推論のウォームアップ時間は、ユーザー入力の計算時間へ含めない
- Bulk trainingはUIをブロックしない実装にする。Web Workerで安定しないbackendの場合は、batch間でメインスレッドへ制御を返す代替経路を用意する

### 14.3 Model revision

- 学習観察モデルは0から始まる単調増加のrevisionを持つ
- Guided training 1回またはBulk training 1batchのcommitごとに1増やす
- traceはbefore / after revisionを保持する
- 推論traceはbeforeとafterが同じrevisionになる
- UIは異なるrevisionの値を同じ比較欄へ混在させない

## 15. Performance and privacy

### Performance budgets

- 初期表示で中心図のskeletonが1秒以内に見える
- 静的アセット読み込み後、学習済みモデルの初回推論が一般的なdesktopで1秒以内を目標とする
- 通常の再推論は100ms以内を目標とするが、計測値を画面へ正直に表示する
- 1件学習の計算は500ms以内を目標とする
- アニメーション中に長い同期処理を実行しない
- 100回連続推論後にTensor数が操作回数へ比例して増えない
- 性能目標を満たさない端末でも結果を省略せず、再生速度とBulk件数を下げて継続できる

性能値は受け入れ基準ではなく目標値とし、実装後に実測環境と結果を記録する。

### Privacy

- 手描き入力、学習状態、推論結果を外部へ送信しない
- analytics、広告、外部AI APIを使わない
- 手描き画像を永続保存しない
- 学習状態をIndexedDBへ保存する機能はVersion 1に含めない
- データとモデルがキャッシュ済みなら、再訪時はオフラインでも主要機能を使える構成を目標とする

## 16. Accessibility

- 主要操作はキーボードだけで完了できる
- CanvasまたはSVGだけに情報を閉じず、現在phase、予測、確率、損失、選択値をHTMLテキストでも提供する
- 0〜9の確率は順序付きリストまたは表として支援技術から読めるようにする
- アニメーションの各frameをlive regionで読み上げず、phase変更時だけ要約を通知する
- 再生中でもフォーカスを移動しない
- 接続選択には最低44×44px相当のhit targetを設ける
- hoverだけに依存せず、クリック、タップ、フォーカスで同じ詳細を開く
- 数式には平易な説明を併記する
- 色覚に依存しない正負、正解、不正解の区別を用意する

## 17. Validation routes

実装時、URL queryまたは同等の開発用導線で次を再現可能にする。

| Route | State |
| --- | --- |
| `/?sample=3&model=learning` | 固定seed・未学習モデルで数字3 |
| `/?demo=wrong` | 学習済みモデルが誤分類する固定testサンプル |
| `/?demo=ambiguous` | 出力上位2クラスが近い固定サンプル |
| `/?demo=training` | Guided trainingのcompare phase |
| `/?demo=gradient` | parameter-update phase |
| `/?demo=bulk` | Bulk training中 |
| `/?demo=draw-empty` | 空の手描きCanvas |
| `/?data-error=1` | データ読み込み失敗 |
| `/?model-error=1` | モデル読み込み失敗 |
| `/?numeric-error=1` | NaN検出と学習停止 |

固定サンプルはモデル更新により条件を満たさなくなる可能性があるため、学習済みmodel manifestの更新時にvalidation routeの期待値も検証する。

## 18. Test specification

### 18.1 Model unit tests

- 固定入力と固定パラメータに対する`z1`、`a1`、logits、Softmax確率が参照計算と一致する
- Softmax確率の合計が許容誤差内で1になる
- 単一サンプルlossが `-log(p[label])` と一致する
- 自動微分の勾配が、抽出した複数パラメータの有限差分近似と許容誤差内で一致する
- SGD更新が `before - learningRate × gradient` と一致する
- 推論ではmodel revisionが変化しない
- Guided trainingではrevisionが1だけ増える
- trace再生、巻き戻し、再再生でrevisionとパラメータが変化しない
- 同じseed、データ順、操作列で同じ予測履歴になる
- NaN / Infinity発生時にcommitせず、最後の正常パラメータを保持する

### 18.2 Trace integrity tests

- traceのprobabilitiesと、parametersBeforeから再計算したprobabilitiesが一致する
- forward contributionが `activation × weight` と一致する
- gradient上位接続が全gradientから正しく選ばれている
- updatesとparametersBeforeの和がparametersAfterに一致する
- traceのmodel revisionと画面表示が一致する
- 表示丸めが元データを変更しない
- phaseごとに参照してよい値以外を先取り表示しない

### 18.3 Dataset tests

- manifestのチェックサムと同梱データが一致する
- 画像数、ラベル数、shape、値域が仕様と一致する
- 各subsetのクラス件数が仕様と一致する
- train sample IDとtest sample IDが重複しない
- Guided sampleがtest splitへ入っていない
- 手描き前処理結果が28×28、0〜1の範囲になる
- 空白入力を推論へ渡さない

### 18.4 Integration and browser tests

- 固定サンプルを選び、推論6phaseを最後まで再生できる
- Guided training 12phaseを再生し、更新前後の値を比較できる
- 再生中の巻き戻しで重みが二重更新されない
- Bulk trainingを停止し、完了済みbatchの状態から続行できる
- 学習済みモデルと学習観察モデルを明確に切り替えられる
- 手描き、消去、再描画、推論がpointerとtouchで動く
- loading、data error、model error、numeric errorから次の操作が分かる
- keyboardだけでモード選択、再生、前後phase、サンプル変更を行える
- reduced motionで情報を失わず、移動演出を停止する
- 375、768、1024、1440pxで文字欠け、重なり、意図しない横スクロールがない
- light / darkのOS設定にかかわらず、固定パレットのコントラストが成立する

## 19. Acceptance criteria

### Product

- 初回3秒以内に「手書き数字を読むニューラルネットの中身を見るアプリ」だと分かる
- 1回のGuided trainingを5分以内に最後まで理解できる
- 推論と学習が別の処理であることを画面構造と文言で説明できる
- 間違った予測を含め、モデルの出力を演出で修正しない
- 学習前後の変化を、確率、損失、重み更新の実値で比較できる

### Scientific integrity

- すべての意味付きアニメーションが`ComputationTrace`内の値へ追跡できる
- 表示された入力、活性値、確率、損失、勾配、更新量がモデル計算とテスト許容誤差内で一致する
- 集約、正規化、丸め、省略を行った表示には、その事実が分かる凡例または詳細がある
- 学習済みモデルとブラウザ学習モデル、trainとtest、計算時間と再生時間を混同させない
- モデルやデータが失敗した場合に、架空の値を表示しない

### Quality

- unit test、integration test、lint、typecheck、buildが通る
- Tensorリーク検査が通る
- validation routesの全状態をブラウザで確認する
- 375pxと1440pxのスクリーンショットを取得し、中心図と主要操作を確認する
- データとモデルのprovenance、ライセンス、評価結果をREADMEまたはmanifestに記載する

## 20. Recommended first playable slice

最初からBulk trainingと手描きを作らず、1サンプルの推論と1回の学習を縦に通す。

1. 固定seedで `784 → 16 → 10` のモデルを初期化する
2. 固定されたtrainサンプルの「3」を読み込む
3. `input → z1 → ReLU → logits → Softmax → prediction` のtraceを作る
4. traceから28×28入力、16活性値、10確率を表示する
5. cross entropy lossと全パラメータの勾配を取得する
6. SGD更新を1回だけ適用する
7. 更新量上位10件と、更新後の同一サンプル予測を表示する
8. 自動テストでtraceとモデル計算の一致を証明する
9. 375pxと1440pxで、前後ステップ操作を実ブラウザ確認する

このsliceで確認する問いは1つに絞る。

> 実際の値を追うことで、モデルが「間違いを測り、重みを少し変える」流れを理解できるか。

## 21. Approved product decisions

次の5点は2026-09-02に承認済みとし、Version 1の実装基準にする。

1. Product nameは「数字がわかるまで」
2. 隠れ層は16ニューロン
3. Version 1の同梱subsetはtrain 5,000件 / test 1,000件
4. Guided trainingに `学習前へ戻す` を必須で含める
5. 初回体験は未学習モデルの固定された数字「3」から始める

## 22. References

- Keras MNIST dataset: https://keras.io/api/datasets/mnist/
- TensorFlow.js training guide: https://www.tensorflow.org/js/guide/train_models
- TensorFlow.js tensors and operations: https://www.tensorflow.org/js/guide/tensors_operations
- TensorFlow.js API: https://js.tensorflow.org/api/latest/
- TensorFlow.js examples, including browser MNIST Core: https://github.com/tensorflow/tfjs-examples
