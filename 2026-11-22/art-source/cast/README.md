# 顔と手の当たり

[顔の比較](face-fit.jpg)は、瞼に合わせて白目と虹彩を収め、眉を既存の肌のUVに描いた段階のBlender画像。[ダイヤルの比較](wheel-contact.jpg)は、真壁が中継機を回す際の手と軸を同じ縮尺で示す。受像機の蝶番が傾くと、手の目標点も縁に沿って動く。撮影したWindowsプレイヤーの画像は evidence に収録する。

頭部と肌の原典は [キャスト素材の記録](../../Game/Assets/Kinsei/Cast/README.md)にある。fit_hair.py はベースの頭部OBJを読み、髪を頭皮に合わせてOBJとテクスチャを書き出す。paint_brows.py は顔のUVと肌の画像を使い、撮影時の眉の位置を描き込む。どちらも引数は `Game/Assets/Resources/KinseiCast` と、あらかじめ作成した出力フォルダー。オフライン制作に Python、NumPy、Pillow を使用する。
