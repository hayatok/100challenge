# Ribbon Rally character source

The editable cast is in `ribbon-rally.blend`. Each numbered GLB in `../game/racers/` contains one 19-bone skeleton, a skinned body and a separate skinned face. The two surfaces share a material and its embedded 1024 × 1024 sRGB atlas. The six facial morphs are on the face mesh. The thirteen body actions are named NLA tracks. Enable a track to preview it in Blender.

## Reference and construction

Nagi's front, profile and rear views come from `art/nagi-turnaround.png`. The six portraits are in `art/racers.png`, and `art/nagi-jump.png` supplies the airborne and grounded silhouettes. The turnaround is calibrated at 255 design pixels per metre when displayed 1,250 pixels wide. The shoes meet row 398. The five rivals have only a frontal design, so their profiles and the backs of their outfits are interpretations.

The head and the overlapping hair sections have separate surfaces. The crown, fringe, cheek locks, bow, visor, braids and tied hair contribute to the silhouette. The sleeves deform across the elbows, the cuffs surround the wrists, and the shoes have raised laces and heel panels. The painted atlas carries hair colour, fabric seams and each runner’s bib. The face mesh follows the head bone. Its brow, lid, iris and mouth shapes change together for focus, surprise and cheering. Two additional closed-eye shapes allow a blink during focus or surprise.

`RacerVisual.gd` samples strides by distance, follows the airborne phase for jumps, and plays the start and finish gestures by elapsed time. The finish differs by runner and rank. The two courses light the same colours for daylight or sunset. The character shader uses the course light for shadows and preserves the colours of the facial features.

## Rebuild

Run from this directory. The atlas tools use Pillow, NumPy and SciPy. The bib uses Arial Bold where installed and falls back to DejaVu Sans Bold. The recorded checks used Blender 5.2.1 and Godot 4.7.2.

```sh
python3 paint_atlas.py /tmp/ribbon-atlases
blender -b --python-exit-code 2 --python build_racers.py -- /tmp/ribbon-atlases
blender -b --python-exit-code 2 --python render_review.py -- /tmp/ribbon-review --single
blender -b --python-exit-code 2 --python render_review.py -- /tmp/ribbon-review
blender -b --python-exit-code 2 --python render_review.py -- /tmp/ribbon-review --sport
blender -b --python-exit-code 2 --python render_review.py -- /tmp/ribbon-review --performance
blender -b --python-exit-code 2 --python measure.py
python3 review_sheets.py /tmp/ribbon-review
blender -b --python-exit-code 2 --python face_review.py -- ../game/racers /tmp/ribbon-faces
python3 face_review.py --sheet /tmp/ribbon-faces review/expressions.webp
godot --headless --path ../game --editor --import
godot --headless --path ../game --script "$PWD/test_import.gd"
```

## Inspection

The [turntable](https://hayatok.github.io/100challenge/2026-11-18/model-review/) shows the six racers before and after the v0.3.1 changes. Drag either picture to rotate both. Nagi also has a v0.2 comparison. The reference drawing under the controls supplies three views for Nagi and a frontal lineup for the other racers.

To capture a revision, import its game into a fresh Godot project cache, then run the current capture script against that game. It uses the revision's GLBs, character materials and daytime course lighting. The camera makes sixteen equal steps, horizontally and at 28° elevation, with a fixed vertical span of 1.86 m. Idle and run are sampled at the same times in all releases. The WebP sheets load only on the comparison page.

```sh
godot --headless --path ../game --editor --import
godot --path ../game --audio-driver Dummy --script "$PWD/turntable.gd" -- "$PWD/review-view/frames/current"
```

The following sheets record v0.3.

- Compare the supplied drawings with [Nagi's turnaround](review/nagi-turnaround.webp), the [fringe and brows from three angles](review/nagi-face.webp) and the [six-racer lineup](review/cast.webp). The [matched game cameras](../docs/verification/v03-character.webp) use the same lens, pose sample and track in the two releases.
- Compare [five expressions per runner](review/expressions.webp), the [preparation and finish gestures](review/performance.webp), [airborne poses](review/motion.webp) and the [sprint, dive and slide](review/sport-motion.webp). The sheets use GLBs imported back into Blender. The facial check also verifies head attachment, clear open eyes and closed lids from three angles.
- [Model measurements](review/measurements.json) include neutral bounds, triangles, dive reach, slide contacts and the left sole through sampled running and landing phases. [Silhouette measurements](review/silhouette.json) compare the masks after aligning heights and horizontal centres. The [play report](../docs/verification/v0.3.md) includes the result and its limitations.
- The Godot import check exercises all six rigs, facial keys, lead-leg variation, sprint stride, dive hold, slide recovery, winning and other finish reactions. A separate course-flow test checks camera obstruction, facial transitions, pausing, retry and reduced motion. The [gameplay film](../docs/verification/v03-performance.mp4) uses the normal race controls.
