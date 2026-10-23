import { defineConfig } from 'vitest/config';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export default defineConfig({
  test: {
    include: ['test/**/*.test.ts', 'src/**/__tests__/*.test.ts', 'src/*.test.ts'],
    environment: 'node',
    pool: 'forks',
  },
  resolve: {
    alias: {
      '@libsql/client': path.resolve(__dirname, './node_modules/@libsql/client/lib-esm/node.js'),
    },
  },
});
