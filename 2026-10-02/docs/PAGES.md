# GitHub Pages publication

This app is registered as `2026-10-02` in the root catalog. The existing repository runner invokes `npm ci`, app `setup`, then app `check`. No shared workflow or earlier app is changed.

- Godot 4.7.2, Compatibility renderer, Web export with threads and GDExtension disabled
- App-owned setup installs official engine/templates and a local Python virtual environment for pinned NumPy when needed
- `check` validates original audio, imports resources, runs 4,392 gameplay assertions and exports `dist/index.html`
- Web output includes relative JS/WASM/PCK paths, public credits, font/engine licenses and a native gameplay screenshot used by the catalog
- Generated output, native exports, caches and Python bytecode remain ignored; Git stores the source project and licensed assets

Target URL: https://hayatok.github.io/100challenge/2026-10-02/

## Local publication checks

- Root catalog/deployment-script tests: 38 passed
- App audio checks, import, 4,392 assertions and Web release export passed in the isolated publication checkout
- Existing original license files preserve upstream whitespace verbatim
- Desktop supports hardware keyboards. Touch Web opens the native English keyboard from the existing game HUD without separate mobile panels; see MOBILE_QA.md for verification boundaries
- Cloud llvmpipe measurements do not establish performance on the user's GPU. User playtesting remains the intended quality check

The repository's existing manual Pages workflow or `release-*` tag must deploy the reviewed main commit. CI/export success alone does not establish a live deployment.
