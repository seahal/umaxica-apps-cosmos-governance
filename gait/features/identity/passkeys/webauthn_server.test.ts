// @vitest-environment node

import { describe, expect, it } from "vitest";

import { passkeysSupported } from "@/features/identity/passkeys/webauthn";

describe("passkeysSupported during server rendering", () => {
  it("reports unsupported when no browser window exists", () => {
    expect(typeof window).toBe("undefined");
    expect(passkeysSupported()).toBe(false);
  });
});
