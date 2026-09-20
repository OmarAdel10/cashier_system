import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    environment: 'node',
    pool: 'forks',
  },
  resolve: {
    alias: {
      '@libsql/client': new URL('./node_modules/@libsql/client/lib/index.js', import.meta.url).pathname,
    },
  },
});
