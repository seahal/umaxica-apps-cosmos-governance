import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

// These entrypoints are thin bootstrap wrappers: each imports the shared "../application" module
// (which wires Turbo and Stimulus controllers) and registers the offline service worker for its
// origin. Importing them here verifies the wiring without exercising
// the real Turbo/service-worker machinery, which is unit-tested independently elsewhere (see
// gait/pwa/register.test.ts and gait/controllers/index.test.js).

const registerOfflineServiceWorker = vi.fn();
const sharedApplicationLoaded = vi.fn();

vi.mock("../../src/pwa/register", () => ({
  registerOfflineServiceWorker,
}));

// Registered per test: `vi.resetModules()` keeps a hoisted mock's evaluated module, so only a fresh
// `doMock` re-runs the factory and lets each import report whether it loaded the shared bootstrap.
beforeEach(() => {
  vi.doMock("../../src/entrypoints/application", () => {
    sharedApplicationLoaded();
    return {};
  });
});

afterEach(() => {
  vi.resetModules();
  registerOfflineServiceWorker.mockClear();
  sharedApplicationLoaded.mockClear();
});

describe.each([
  ["base/app", "../../src/entrypoints/base/app.ts"],
  ["base/com", "../../src/entrypoints/base/com.ts"],
  ["base/org", "../../src/entrypoints/base/org.ts"],
])("%s entrypoint", (_surface, modulePath) => {
  it("imports the shared application bootstrap and registers the offline service worker", async () => {
    await import(modulePath);

    expect(sharedApplicationLoaded).toHaveBeenCalledTimes(1);
    expect(registerOfflineServiceWorker).toHaveBeenCalledTimes(1);
  });
});
