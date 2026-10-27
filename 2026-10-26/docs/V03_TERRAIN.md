# v0.3 calm Sunlit Tideglass terrain

## Production brief

Purpose: quiet the ground and water behind the new crew and portrait family while preserving a bright harbor adventure. The R2 market-map fixture shows high-frequency white water caustics and granular repetitive paving. Replace these with smooth hand-painted anime background planes, readable at a 128 by 128 game patch. This document and native-size tile composites are asset evidence; actual game integration and play checks belong to the parent.

One opaque square atlas contains four exact equal quadrants with no gutters, dividers or labels. Top left is pale honey-limestone floor with approximately five to nine large irregular pavers, few thin low-contrast joints. Top right is slightly darker warm limestone wall-top blocks, viewed flat from directly overhead. Bottom left is honey-colored weathered wide timber walkway planks. Bottom right is calm luminous turquoise water with broad soft tonal bands and very few thin restrained light strokes. No foamy waves, white sparkle clusters, seabed, objects or reflected scenery. Each quadrant maps to a 2 by 2 game-cell patch (128 logical units), so all materials must share scale and surface-level orthographic view.

Use cream and pale honey stone, muted warm sand joints, honey wood, and medium turquoise water. Keep upper-left sunlight soft and flat, without cast object shadows, heavy bevels or dark corners. Use clean smooth painted color masses with controlled edge definition, matching the new anime portrait family. No photoreal texture, grain, stippling, tiny repeated flecks, perspective, characters, props, scene composition, gridlines, text, frames or signatures.

Each quadrant is its own seamless repeat unit: opposing edges must meet in color and surface features; the corners must contain only that quadrant's material. Neighboring quadrants must meet at exact center axes without mixed strips. Source target is 1024 square or 1536 square; final atlas is 1024 by 1024 PNG. Preserve the original outside res://. Only uniform resize, measured crop and QA repetition/compositing are permitted; do not repaint pixels.

## Budget and QA

Built-in image generation only, maximum two calls: one atlas plus one corrective edit if the representative fails. Before acceptance, inspect every quadrant repeated 3 by 3 at 128-pixel patch size, the complete atlas, four corners and exact center axes. Reject strong repeat seams, corner material contamination and noisy white water. Record prompts, original paths, hashes, quadrant bounds, native-size QA and any unresolved source limitation in the manifest. The parent owns board code, actual map screenshots and mandatory integrated Astra review.

## Selected source and limitations

Both approved calls were used. Call 1 reduced the old white sparkle but retained a caustic network and paint flecks; call 2 replaces those with broad smooth turquoise bands and simpler stone/wood planes. The selected generated source is 1254 square with exact material axes at x=627 and y=627, uniformly resized to 1024 square. Its four measured quadrants are each 512 square. Source files and 3 by 3 native-size QA remain in `.scratch/versions/v03/terrain/`; prompts, hashes and bounds are in the shipped manifest.

Inspected the full source and `tiles-v2-qa.png`, where each patch is 128 pixels. The water has no white sparkle or caustic net, and ground planes are substantially calmer. Corners contain the correct material; no divider, label, object or perspective appears. Source acceptance is provisional for parent integration. Repetition is still perceptible in the paver layout, wood knots and broad water-band rhythm; minor water edge tone transitions remain. This is not a mathematically seamless texture. No pixels were repaired outside image generation and no further calls are authorized. Actual map-scale screenshots, character/number readability and play acceptance remain parent checks.
