import { defineConfig } from '@playwright/test';

const workspaceDir = process.env.HARNESS_WORKSPACE_DIR || 'workspace';
const backendURL = process.env.API_BASE_URL || 'http://127.0.0.1:4174';
const frontendURL = process.env.E2E_BASE_URL || 'http://127.0.0.1:5173';

export default defineConfig({
  testDir: workspaceDir,
  timeout: 30_000,
  expect: {
    timeout: 5_000,
  },
  fullyParallel: false,
  workers: 1,
  reporter: [['line']],
  use: {
    baseURL: frontendURL,
    trace: 'retain-on-failure',
  },
  projects: [
    {
      name: 'api',
      testMatch: /tests\/api\/.*\.spec\.ts/,
      use: {
        baseURL: backendURL,
      },
    },
    {
      name: 'e2e',
      testMatch: /tests\/e2e\/.*\.spec\.ts/,
      use: {
        baseURL: frontendURL,
      },
    },
  ],
});
