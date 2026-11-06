import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  resolve: {
    alias: [
      { find: /^react-native$/, replacement: fileURLToPath(new URL('./src/test/react-native.ts', import.meta.url)) },
      { find: /^@\//, replacement: `${fileURLToPath(new URL('./src/', import.meta.url))}` },
    ],
  },
  test: { environment: 'node' },
});
