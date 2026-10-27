# SHIOGAERI v0.3 verification

Recorded2026-10-28 JST, based on the reviewed v0.2 commit c750371. This is the second version of the first Pages pair. The user's latest instruction is to publish this version, verify the public game and then stop; no v0.4 work is included.

## Delivered presentation

All four adult workers use full directional down/up/side contact pairs, with alternating contacts, measured hand sockets, a small salvage hook, editable attack/recoil/idle and arrival/quiet-arrival/loss clips. The old rectangular boot slices are removed. The receipt instantiates the same actor, while its actual item list, count, value and return button remain immediately available. The hook is presentation equipment rather than a model of the equipped item.

Four cleaner portraits and face crops replace the granular legacy family in the harbor, conversations and HUD. Conversation names, roles, current dialogue and personal-job state remain tied to rules data. The new four-part terrain atlas replaces the highly glittering water and busy small stone texture with calmer turquoise bands and larger limestone shapes. District palette, architecture, authored blocked anchors, water behavior and fog remain district-specific.

The motion family used7 built-in image calls, portraits5 and terrain2, within their documented production caps. Source originals/prompts/normalization and alpha/crop QA are recorded in the v03 art manifests and briefs. Motion originals and contact-sheet QA are excluded from the Web pack; portrait/terrain originals remain outside res://. Source previews do not prove in-game motion.

## Automated and native evidence

- Final combined `npm run check` passed:5,328 rules assertions,469 UI/store assertions and single-thread Compatibility Web export. See[check output](check-output.txt). Root tests passed38/38.
- The existing208 UI assertions are retained. Added tests cover both phone sizes/all portraits and dialogue navigation; actual rules-derived successful, empty and failed receipts; exact inventory/value; immediate return; production modal/focus freeze/resume; static reduced outcomes; and live changes through the actual settings CheckButton. QA protection is restored before every wait and state-changing action.
- The actor probe passed132 checks; region probe120. The scene/resource checker passed162 files with0 errors/0 warnings. Native motion frames, state invariance, direction/contact/tool/queue/pause tests and their limits are in[actor verification](actor/ACTOR_MOTION.md).
- Native scene captures use390x844,360x740 and1280x900 window pixels. Godot's logical canvas may expand under its stretch policy; touch bounds are also checked after conversion to physical phone pixels. Combat placements and unlocked districts in these fixtures are labelled fixtures rather than earned campaigns.

## Actual exported Web operation

Fresh QA origin localhost:4333 was operated through the browser UI. Read-only DOM measurement confirmed390x844 and360x740; desktop1280x900 was also inspected. All four portraits, names, roles, dialogue and close controls were operated. The[small conversation](web-crew-small.jpg) and[wide harbor](web-harbor-wide.jpg) remained readable and usable.

All four workers departed and moved in multiple directions. Sui recovered the actual nearby scrap and medicine and returned after7 turns with2 stored items worth14pt; the borrowed knife was returned separately. Isana returned after6 turns with0 items and0pt, with an empty item list and quiet arrival. Ritsu's directional miniature and a further empty return were also operated. Kohaku approached a generated wader, traded a real bump attack and damage, and was deliberately left in its attack path. Death on turn32 showed the lost borrowed knife,0pt, the actual cause and a loss stance. Returning to the harbor retained the10 stored items accumulated before that death. These are agent-operated routes, not human acceptance tests.

Selected screenshots:[Sui front](web-field-sui-front.jpg),[back](web-field-sui-back.jpg),[side](web-field-sui-side.jpg),[Isana](web-field-isana.jpg),[Ritsu](web-field-ritsu.jpg),[Kohaku](web-field-kohaku.jpg),[two-item return](web-return-sui.jpg),[empty return](web-empty-return-isana.jpg),[combat](web-combat-kohaku.jpg),[loss](web-loss-reduced.jpg).

The existing localhost:4331 saved session was reloaded under v0.3 and only continued/read: it showed Ritsu in the canal on turn40, HP18/28 with3 carried items at an853x978 DOM viewport. No turn action was sent to that session. This differs from the earlier v0.2 QA checkpoint, so it is recorded as an observed saved run rather than an assertion that its old harbor counts are unchanged; see[saved run](web-saved-run-observed.jpg). Original player origins4316/4327 were left untouched. Error-level browser logs for both operated tabs were empty.

## Review correction and Japanese checks

The initial mandatory ai_slop_reviewer / gpt-6-astra review found one medium issue: changing reduced motion from a receipt's settings did not reach the existing actor stage. The settings callback now propagates the preference; the stage immediately selects its static outcome and holds it when full motion is restored, without replaying the receipt or changing ownership. The28 added assertions use the actual CheckButton, across arrival/quiet-arrival/loss. An initial stopped-clip clock probe was corrected because Godot rejects reading the position of a cleared clip; the final tests inspect stable visible pose and stopped playback instead.

The exact UI operation was also repeated on Web: settings opened during Kohaku's loss clip, reduced motion was enabled, the modal closed into a static loss stance, then the preference was disabled without replaying the loss or changing the receipt. See[live preference](web-live-reduced-setting.jpg). The final ai_slop_reviewer / gpt-6-astra follow-up reported no findings and confirmed that the medium issue is resolved. The reviewer inspected code, records and saved images; it did not independently run the game.

Four changed Japanese-bearing files have direct Bash CLI lint/run/verify records matching their final hashes; see[Japanese record](japanese-review.json). Necessary GDScript colons, clear repeated save instructions and the existing comma before a district list were retained after reading the actual text. Counts/hashes are not prose-quality scores.

## Release checkpoint and limits

Local full-site preparation and current-head CI/publication are tracked in Issue214 and PR212. The first CLI baseline download timed out, including a bounded240-second retry. The GitHub connector then supplied the retained Linux Pages archive from run40127401978; its465,445,330 bytes and SHA-256 matched artifact metadata before safe extraction. The deployment planner correctly selected a full rebuild because shared skill files had changed since that published baseline. It was not forced to reuse stale outputs.

Publication is not claimed in this pre-release record; the exact merged SHA, tag, Actions result, public HTTP/game operation and Linux-artifact comparison belong to the release closeout in Issue214. The earlier proposed continuation automation could not be paused because the app reported it no longer exists; the goal query returned no active goal. No new automation or goal was created. Development will stop after the requested public checkpoint.

There are two contact poses per facing and no dedicated passing pose or continuous joint rig. Repeated terrain patterns and a small water-edge tone difference remain. Physical iPhone/Android, Safari, audio listening, long sessions, human first-play acceptance and commercial release readiness remain unverified. The automated all-district campaigns in v0.2 and the native unlocked-map fixtures are not a claimed human or Web full-campaign playthrough.
