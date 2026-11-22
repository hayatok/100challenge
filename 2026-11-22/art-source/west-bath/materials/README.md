# 西の湯の五つの表面

Windows機のComfyUIでMOSS-Imageを実行し、5点とも1024 × 1024の原本を保存した。玄関の釉薬は一枚のタイル、洗い出し石は幅約20 cm、木綿は幅約8 cm、型硝子は幅約12 cmの部分に相当する。ゴムの原画は客が足を返す中央だけ畝が浅い。

|原本|ゲーム内で使う場所|生成記録|
|---|---|---|
|[青緑の釉薬](Tile.png)|玄関の小口タイル。目地は壁側に作る。|[Tile.json](Tile.json)|
|[洗い出し石](Terrazzo.png)|運河橋の親柱と短い欄干。肌色の長石と黒い骨材を含む。|[Terrazzo.json](Terrazzo.json)|
|[葡萄色の木綿](Noren.png)|三枚に割れた暖簾の生地。染め抜きの「ゆ」をこの上に重ねる。|[Noren.json](Noren.json)|
|[ゴムの畝](Mat.png)|土間の踏み込みに敷くゴムマット。|[Mat.json](Mat.json)|
|[笹の葉に似た型板硝子](Glass.png)|脱衣場側の四枚戸と番台のガラス。生成した凹凸模様に斜めの金網を重ね、奥の灯りが明るい部分ほど細い溝が浮く。|[Glass.json](Glass.json)|

ComfyUIの実行グラフは[graph.json](graph.json)。拡散モデルは `moss_image_sft_int8_convrot.safetensors`、エンコーダーは `qwen3.5_9b_w4a8_gptq.safetensors`、VAEは `flux2-vae_small.safetensors`。ステップ30、CFG 2.5、er_sde・simpleを使った。各記録に正負のプロンプト、seed、ローカルのprompt ID、実行時刻、サーバー上の出力名と原本のSHA-256を収録した。

再生成する場合はComfyUIをローカルの8188番ポートで起動し、[generate.py](generate.py)を実行する。[prepare.py](prepare.py)は原本のSHA-256を照合し、反復時に継ぎ目が出ないよう両端40 pxの色をなじませる。出力は `Game/Assets/Resources/KinseiWestBath/` の5枚のJPG。
