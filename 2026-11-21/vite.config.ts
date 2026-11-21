import { readFileSync } from 'node:fs';
import { defineConfig } from 'vite';

export default defineConfig({
  base: './',
  plugins: [{
    name: 'include-three-license',
    generateBundle() {
      const license = readFileSync(new URL('./node_modules/three/LICENSE', import.meta.url), 'utf8');
      this.emitFile({ type: 'asset', fileName: 'THREE-LICENSE.txt', source: license });
    },
  }],
});
