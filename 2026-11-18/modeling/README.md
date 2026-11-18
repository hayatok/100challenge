# Ribbon Rally character source

The six numbered GLBs in `../game/racers/` each contain one painted mesh, one embedded 1024 × 1024 sRGB atlas and one 19-bone skeleton. The editable lineup is `ribbon-rally.blend`. Each racer's seven actions are on named NLA tracks. Enable one track to preview it in Blender. The game chooses a clip and samples it at the race simulation's phase through `RacerVisual.gd`.

## Reference and scale

| Item | Construction reference |
| --- | --- |
| Asset and category | CH_Nagi, CH_Suzu, CH_Rikka, CH_An, CH_Nene and CH_Mio, stylised human bipeds for a mobile portrait race. |
| Views | Nagi's orthographic front, left and rear views come from `art/nagi-turnaround.png`. The six faces come from `art/racers.png`. Nagi's four airborne and grounded silhouettes come from `art/nagi-jump.png`. |
| Scale | The turnaround is calibrated at 255 design pixels per metre when displayed 1,250 pixels wide. The sole plane is at row 398. Nagi measures 1.500 m tall including her bow. |
| Proportions | On the front turnaround the hair begins at row 21, the jaw ends near 192, the shoulders start near 200, the jacket hem falls at 269, the shorts end near 300, the socks begin near 323 and the soles reach 398. The bob spans about 224 pixels at its widest point, the shirt about 80 and each shoe about 65. |
| Articulation | Pelvis, chest, head, paired upper arms, forearms, hands, thighs, shins, feet and side locks. Two additional bones control an ornament and blinking. The ankles rotate at the shoe collars. |
| Material | Projected albedo supplies the painted face, hair, jacket and shoe details. The silhouette, folded bow, ponytail, braids, hair buns, visor, cuffs, hands, shoe soles and laces have physical depth. |
| Inferred surfaces | Five rivals have a frontal cast sheet. Their profiles, backs, hair winding and costume seams use the front silhouette and Nagi's turnaround as guides. Her side and front sheets place the bow at slightly different depths. |
| Target | Godot 4.7.2 GL Compatibility, GLB with in-place animation. The import preset embeds Basis Universal textures and generates mesh LODs. |

## Rebuild

Run from this directory. The atlas tools use Pillow, NumPy and SciPy. The bib uses Arial Bold when available, with DejaVu Sans Bold as a fallback. The external Python packages are build-time dependencies. Installed Blender 5.2.1 and Godot 4.7.2 were used for the recorded checks.

```sh
python3 paint_atlas.py /tmp/ribbon-atlases
blender -b --python-exit-code 2 --python build_racers.py -- /tmp/ribbon-atlases
blender -b --python-exit-code 2 --python render_review.py -- /tmp/ribbon-review --single
blender -b --python-exit-code 2 --python render_review.py -- /tmp/ribbon-review
blender -b --python-exit-code 2 --python measure.py
python3 review_sheets.py /tmp/ribbon-review
godot --headless --path ../game --editor --import
godot --headless --path ../game --script "$PWD/test_import.gd"
```

## Model checks

- [Turnaround comparison](review/nagi-turnaround.webp) places the supplied front, side and rear views above the exported model. After matching silhouette height and centring the bounding boxes, their intersection-over-union scores are 0.862, 0.841 and 0.874. The differences are most visible around the temples, the shape of the bow from the side and the rear of the shoes. The face and clothing retain painted highlights.
- [Six-racer comparison](review/cast.webp) includes the source sheet and both sides of the exported lineup. [Pose comparison](review/motion.webp) shows six sampled Nagi poses. These are renders of imported GLBs in Blender.
- [Measurements](review/measurements.json) records the six neutral bounds, triangle counts and sampled sole heights after GLB round-trip. Heights range from 1.411 to 1.531 m. Each asset contains 26,444–33,684 triangles before engine LOD. During Nagi's left-foot support, the sole is 0.6–6.6 mm above the reference plane at the sampled phases up to 0.25, and lifts to 18.3 mm at phase 0.28. The sampled landing sole ranges from 4.5 mm below to 1.1 mm above the plane.
- In an independent Godot import all six models loaded, all seven clips were available and each delivered one skinned surface. Sampling the run every twentieth of a cycle measured a maximum left-thigh rotation change of 1.461 radians relative to its starting orientation for every racer. The race controls determine the trajectory of each airborne character.
