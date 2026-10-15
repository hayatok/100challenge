import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  base: './',
  optimizeDeps: { include: ['@paddleocr/paddleocr-js', '@techstark/opencv-js', 'onnxruntime-web'] },
  worker: { format: 'es' },
  build: { assetsInlineLimit: 0 },
  server: { headers: { 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp' } },
  preview: { headers: { 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp' } },
  test: { include: ['tests/**/*.test.ts'] },
});
