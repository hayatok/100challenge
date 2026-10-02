# BLACK RELAY / 黒雨の街 · Urban slice

## Approved milestone

One dense shopping-street route before expanding the campaign. One full word kills one zombie; short CUT is an optional near-threat stagger. The game is an original urban typing rail shooter, with licensed human/weapon/surface assets where appropriate. It is not a port of the September28 game.

## Route and encounter contract

The authored route advances47m over75seconds of camera travel, with first contact, storefront exits, a breather, crossing pressure and a final crowd. This is a pacing target, not a loss timer. A close living threat holds the camera before it can pass the target. The first contact stays alone and cannot damage the player. Active encounter time continues while the rail holds; remaining threats keep the run active at the exit.

24 encounters, maximum4 active enemies. The data timeline is in main.gd. Difficulties explicitly affect enemy speed, telegraph length, health and word length. No secret adaptive penalties.

## Combat and feedback

Common alternate romaji are accepted. Wrong keys preserve progress. Each enemy retains partial input when switching. Automatic selection happens immediately after a kill; the full-size corpse then finishes its1.55second skeleton animation. Thus an upright body during the first hit frame may already be dead and omitted from active-threat counts. No input-blocking hitstop is used.

CUT appears only near a threat or during an attack. Once started it stays available until completed. An attack-window CUT staggers the crowd. Clean kills increase score multiplier, quick kills connect a4second chain, and clearing a group awards a chain bonus. Positive feedback is placed away from the fixed word panel.

## Visual/readability contract

Grounded night-city colors: dark blue/charcoal, warm shop light, pale words, amber focus/rewards, coral errors. Compact health/score HUD; distance to exit instead of a misleading deadline. No target means no large word panel. UI is composed in a1280×720 safe region and centered at other aspect ratios.

Connected first-person hands and pistol sit low-right. Skinned human enemies vary cloth/skin tint, animation phase and slight body scale. The street uses original procedural storefronts/interiors/props, licensed PBR maps, a single static reflection probe, a small local-light budget, distance culling and instanced geometry. A near oblique shadow key grounds characters. These implementation choices do not establish subjective visual superiority.

## Profiles and accessibility

Native hardware profile keeps full3D resolution with2×MSAA. Web uses85%3D resolution, single-thread WebGL2 and fewer active lights. Detected software rendering uses70%3D resolution with full-resolution UI; this is labeled in settings and can be overridden with --native-quality for visual inspection. GPU performance is unverified in the development cloud.

Reduced motion disables camera bob/shake, preserving necessary route traversal. High contrast, volume/mute, pause, checkpoint retry and local difficulty×language records remain. New urban records are separate from old station-campaign records.

## Boundaries

No account, telemetry, purchases or online score board. No commercial franchise assets. No claim to a full campaign or commercial-scale art budget. User requested Web publication for hands-on assessment and reduced further local rendering tests; final browser assessment belongs to that deployment pass.


## Mobile Web controls

The desktop HUD keeps its 1280×720 safe frame. Touch browsers add native HTML buttons and a real text input, with a mirrored current word outside the scaled canvas so it remains readable above the software keyboard. Controls are at least 44 CSS pixels and retain the game's charcoal/ivory/amber color roles, an intentional game-specific exception to the shared light UI palette. The briefing also has an actual clickable START button in the Godot HUD.

The browser input is focused synchronously by a player gesture, never by the frame loop. VisualViewport resize/scroll updates keep controls inside the visible area; short landscape layouts may scroll. Character input uses committed input/composition events, not synthetic keyboard events. ASCII romaji and English are accepted by the existing matcher; kana text is not automatically converted into a correct answer. Paste/drop and predictive replacement are blocked. Backspace/reset clears the selected target, matching desktop behavior. Leaving the page pauses the encounter; returning requires an explicit resume.
