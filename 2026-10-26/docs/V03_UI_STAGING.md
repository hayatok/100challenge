# v0.3 crew and receipt staging

Goal: make the four workers recognizable in the harbor, conversation and field, and give successful returns and losses visibly different responses. Context: the v0.2 campaign, Sunlit Tideglass UI, the approved directional crew family and the new adult portrait brief. Keep the same rules, storage schema, deliberate input and economic consequences.

## Composition

The harbor retains its responsive portrait/loadout composition and persistent departure control. Replace the granular legacy portrait and cropped avatars with the cleaner portrait family. Keep the teal compass surround, warm paper, clear adult faces and character accent colors. Retain each worker's brief harbor quote so the loadout remains reachable; the conversation opens a larger portrait beside the worker's name and role, followed by actual campaign dialogue and the real personal-job state.

The receipt uses an editable native actor on a small compass stage, showing the same clothes and directional art as the expedition. A successful arrival plants a step and lowers the tool; a loss contracts the stance and holds it. The written outcome, actual receipt count/value, item list and return button remain immediately available. Empty successful returns use relief without treasure celebration. The actor is decorative and cannot change the receipt, restore gear or award money.

## Motion and lifecycle

The stage delegates animation to the shared actor scene, scales uniformly around its foot origin and repositions only when its container resizes. It does not play a second whole-portrait floating loop. Opening an overlay freezes background actors; a conversation portrait inside the overlay stays visible. Focus loss freezes all stages, and resuming continues rather than replaying arrival/loss. Reduced motion selects the final appropriate stance immediately. Leaving the screen frees stages and queued motion with it.

Field hit responses receive the real attacker-to-victim direction. The world and ownership resolve before these decorative responses, and a new deliberate input remains accepted while presentation plays. Exclude source-only sprite sheets and QA contact sheets from the Web pack.

## Done when

Inspect all four portraits/avatars and conversations at390x844 and360x740, plus the desktop harbor. Operate successful, empty and failed receipts, including immediate return, focus/modal pause and reduced motion; confirm truthful item/value rendering and keyboard reachability. Inspect actual native and exported Web character sequences, alongside the actor worker's directional, contact, tool and fog checks. Run existing rules, UI/store and export checks, then Japanese hash review and mandatory Astra review. Asset QA, agent operation and human playtesting are separate evidence.
