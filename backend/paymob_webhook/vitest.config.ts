import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['src/**/__tests__/*.test.ts', 'src/**/__tests__/*.fuzz.test.ts', 'src/runtime.test.ts'],
    environment: 'node',
    pool: 'forks',
  },
});
