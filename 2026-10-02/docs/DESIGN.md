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


## Mobile Web keyboard

The Godot HUD is the only visible game UI on all devices. There are no separate HTML menus, mirrored words, combat panels, keyboard buttons or visible text fields on touch browsers. The existing briefing START and pause-menu actions remain tappable; the existing pause footer gains a hitbox. Enemy taps still select a target.

A transparent 1×1 CSS-pixel HTML input provides the native keyboard. It stays in the visible viewport with a 16px font and `pointer-events:none`; it cannot cover the game or intercept touches. The canvas handles a single touch gesture synchronously through JavaScriptBridge, using the same Godot HUD hit tests and target-selection code as mouse input. The handled touch prevents the engine's duplicate buffered touch-to-mouse path. Cancelled gestures, drags and multiple fingers activate nothing; desktop mouse and keyboard inputs keep their existing path.

After the in-game action confirms a playing state, focus happens inside that same touchend gesture. Tapping the game reopens a dismissed keyboard, including when iOS retains the input as activeElement. State/frame updates never focus it. VisualViewport resize/scroll fits the canvas above the keyboard without a separate control layer.

Character input uses committed input/composition events, not synthetic keyboard events. ASCII romaji and English go through the existing matcher; kana text is not automatically converted into a correct answer. Paste/drop and predictive replacement remain blocked. Backspace resets the selected target. Leaving the page pauses the encounter; returning requires the existing in-game resume action.
