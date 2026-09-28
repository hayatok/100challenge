import { defineConfig } from 'vite';
import { readFileSync } from 'node:fs';

export default defineConfig({
  base: './',
  build: { target: 'es2022', chunkSizeWarningLimit: 700 },
  plugins: [{
    name: 'distribute-asset-notices',
    generateBundle() {
      const notices = readFileSync(new URL('./THIRD_PARTY_NOTICES.md', import.meta.url), 'utf8');
      const threeLicense = readFileSync(new URL('./node_modules/three/LICENSE', import.meta.url), 'utf8');
      this.emitFile({type:'asset', fileName:'THIRD_PARTY_NOTICES.txt', source:`${notices}\n\n## Three.js full license\n\n${threeLicense}`});
    },
  }],
});
