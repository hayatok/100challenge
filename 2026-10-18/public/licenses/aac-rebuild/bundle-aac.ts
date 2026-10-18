/*!
 * Derived from Mediabunny scripts/bundle.ts at 8dee3638fb1755e58b88d4432e344c5916027e76.
 * Copyright (c) 2026-present, Vanilagy and contributors
 * This Source Code Form is subject to the Mozilla Public License, v. 2.0.
 * https://mozilla.org/MPL/2.0/
 */
import * as esbuild from 'esbuild';
import { inlineWorkerPlugin } from './esbuild/inlined-workers.js';

await esbuild.build({
  entryPoints: ['packages/aac-encoder/src/index.ts'],
  bundle: true,
  target: 'es2021',
  format: 'esm',
  external: ['mediabunny'],
  legalComments: 'none',
  plugins: [inlineWorkerPlugin({
    define: { 'import.meta.url': '""' },
    legalComments: 'none',
  })],
  banner: { js: `/*!
 * Copyright (c) 2026-present, Vanilagy and contributors
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */` },
  outfile: 'packages/aac-encoder/dist/bundles/mediabunny-aac-encoder.mjs',
});
