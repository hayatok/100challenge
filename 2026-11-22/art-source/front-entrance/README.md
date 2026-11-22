# 金星へ踏み込む前の通り

金星に入る前、プレイヤーは真壁の肩や顔、入口の奥にいる相手、壁の受像機を同じ画面で見る。v1.6の正面画面をGPT Imageに渡し、入口と人物の位置をそろえて白熱灯と街頭テレビの配光を検討した。[正面の原画](entrance-in-use.png)・[使用した指示](entrance-prompt.txt)

庇の厚みと壁への取り付けは、GPT Imageで別に作った[照明と外壁の断面図](canopy-section.png)で比較できる。[使用した指示](section-prompt.txt)

ComfyUIのMOSS-Imageで幅64 cmの[明るい磨き石](Stone.png)、幅50 cmの[黒テラゾ](Skirting.png)、幅24 cmの[手入れされた真鍮](Brass.png)を生成した。三枚をそれぞれUnityの外壁、巾木、見切り材に使った。石の法線は骨材の縁の微細な凹凸から作った。[生成処理](make_materials.py)・[Unityへの変換](prepare.py)

各実行のモデル、指示、シード、出力原本のSHA-256をComfyUIのグラフとともに記録した。[磨き石](Stone.json)・[テラゾ](Skirting.json)・[真鍮](Brass.json)
