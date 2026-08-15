/**
 * CJS stub for `jose`, mapped in via jest.config.ts `moduleNameMapper`.
 *
 * WHY THIS EXISTS
 * firebase-admin 14 reaches `jose` through jwks-rsa, and jose 6 is pure ESM
 * (`"type": "module"`, no CJS build). Jest runs this suite as CommonJS, so the
 * bare `export {...}` in jose's entry point is a SyntaxError the moment any
 * test imports `firebase-functions/v2/https`.
 *
 * WHY STUBBING IS SAFE HERE
 * jose is only used to verify JWTs / fetch JWKS when the Admin SDK validates a
 * real ID token. These tests never do that: every callable is invoked directly
 * with a hand-built auth context (see test/helpers/callables.ts), so no token
 * verification path is exercised. Nothing under test reads this module.
 *
 * The throw is deliberate — if a future test does reach a JWT path, it should
 * fail loudly here rather than silently pass against a fake verifier.
 */

const notStubbed = (name) => () => {
  throw new Error(
    `jose.${name}() was called, but jose is stubbed in tests (test/joseStub.js). ` +
      "A test now exercises real JWT verification — replace this stub with the " +
      "real module and configure Jest for ESM."
  );
};

module.exports = new Proxy(
  {},
  {
    get: (_target, prop) => {
      if (prop === "__esModule") return true;
      return notStubbed(String(prop));
    },
  }
);
