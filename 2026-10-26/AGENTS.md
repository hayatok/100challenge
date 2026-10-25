# SHIOGAERI / 潮還り

This is a browser-local, turn-based extraction roguelike for touch screens. Read `docs/PLAN.md` and `docs/CONTRACT.md` before editing. The initial work is one complete expedition, not a release authorization.

- Use Godot 4.7.2, GDScript and the Compatibility renderer, with single-thread Web export. Scenes, resources, animations and controls must be editable in Godot.
- Keep deterministic rules in `game/scripts/rules.gd` and `game/scripts/world_data.gd`. UI, animation, sound and storage cannot advance a turn.
- Carry-in equipment and expedition loot are all lost on death. Stash contents remain. Extraction transfers surviving inventory exactly once.
- Reading, menus, hidden tabs and reloading never advance time. Persist the complete resolved turn. Validate saved data and show storage errors.
- The first playable includes title, harbor/loadout, expedition HUD, inventory, settings/help, extraction and death screens. Controls must work with touch and keyboard.
- Main phone target: 390 x 844 CSS px. Check 360 x 740 and desktop. Use 44px touch targets; keep safe area insets. Directional movement resolves once per explicit input.
- Follow `docs/PLAN.md` and `docs/ART_DIRECTION.md` before generating assets. Verify character identity, alpha, crops and game-scale readability. Keep prompts and provenance in `game/assets/art/`.
- Commands: `npm test`, `npm run check`, `npm run build`, `npm run dev` (Godot editor), `npm run preview -- --port 4316` (Web build).
- Keep verification under `docs/verification/`. Follow the user's root instructions for Japanese review and the mandatory Astra review. Do not publish, tag or merge as part of this milestone.
