import type { Config } from "jest";

const config: Config = {
  preset: "ts-jest",
  testEnvironment: "node",
  testMatch: ["**/test/**/*.test.ts"],
  setupFiles: ["<rootDir>/test/envSetup.ts"],
  testTimeout: 20000,
  // jose 6 (via firebase-admin 14 -> jwks-rsa) is ESM-only and cannot be
  // require()d from this CJS suite. Nothing under test verifies a JWT — see
  // test/joseStub.js for the full rationale.
  moduleNameMapper: {
    "^jose$": "<rootDir>/test/joseStub.js",
  },
  transform: {
    "^.+\\.ts$": [
      "ts-jest",
      {
        tsconfig: "<rootDir>/tsconfig.test.json",
      },
    ],
  },
};

export default config;
