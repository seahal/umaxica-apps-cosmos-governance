import { describe, expect, it } from "vitest";

const pageModules = import.meta.glob<{ default: React.ComponentType }>("@/pages/**/*.tsx", {
  eager: true,
});

describe("React page entrypoints", () => {
  it("loads every page as a renderable component", () => {
    expect(Object.keys(pageModules).length).toBeGreaterThan(0);

    for (const [path, module] of Object.entries(pageModules)) {
      expect(module.default, `${path} must export a page component`).toEqual(expect.any(Function));
    }
  });
});
