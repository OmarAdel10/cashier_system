import { defineConfig } from 'vitest/config';
import path from 'path';

export default defineConfig({
  test: {
    include: ['test/**/*.test.ts', 'src/**/__tests__/**/*.test.ts'],
    environment: 'node',
    pool: 'forks',
  },
  resolve: {
    alias: {
      '@libsql/client': new URL('./node_modules/@libsql/client/lib/index.js', import.meta.url).pathname,
      'daftari-backend-shared': path.resolve(__dirname, '../shared/src'),
    },
  },
});
