import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { present } from "../../../support/present";

const { waitForTurnstileApi } = vi.hoisted(() => ({ waitForTurnstileApi: vi.fn() }));

vi.mock("@/lib/turnstile", () => ({ waitForTurnstileApi }));

const { solveInvisibleTurnstile } = await import("@/features/identity/passkeys/invisibleTurnstile");

type RenderOptions = Parameters<NonNullable<Window["turnstile"]>["render"]>[1];

let rendered: { host: HTMLElement; options: RenderOptions }[];
let turnstile: NonNullable<Window["turnstile"]>;

beforeEach(() => {
  rendered = [];
  turnstile = {
    render: vi.fn((host: HTMLElement, options: RenderOptions) => {
      rendered.push({ host, options });
      return "widget-1";
    }),
    execute: vi.fn(),
    remove: vi.fn(),
  };
  vi.mocked(waitForTurnstileApi).mockResolvedValue(turnstile);
});

afterEach(() => {
  document.body.replaceChildren();
  vi.clearAllMocks();
});

describe("solveInvisibleTurnstile", () => {
  it("renders a hidden invisible widget in the supplied host and resolves its token", async () => {
    const host = document.createElement("section");
    document.body.append(host);
    const promise = solveInvisibleTurnstile("site-key", "Check failed", host);

    await vi.waitFor(() => expect(rendered).toHaveLength(1));
    const widget = present(rendered.at(0), "the rendered Turnstile widget");

    expect(widget.host.parentElement).toBe(host);
    expect(widget.host.hidden).toBe(true);
    expect(widget.options).toMatchObject({ sitekey: "site-key", size: "invisible" });
    widget.options.callback("turnstile-token");

    await expect(promise).resolves.toBe("turnstile-token");
  });

  it("uses the document body when the caller has no host", async () => {
    const promise = solveInvisibleTurnstile("site-key", "Check failed", null);

    await vi.waitFor(() => expect(rendered).toHaveLength(1));
    const widget = present(rendered.at(0), "the rendered Turnstile widget");
    expect(widget.host.parentElement).toBe(document.body);
    widget.options.callback("body-token");

    await expect(promise).resolves.toBe("body-token");
  });

  it("rejects before loading the API when the site key is empty", async () => {
    await expect(solveInvisibleTurnstile("", "Check failed", null)).rejects.toThrow("Check failed");
    expect(waitForTurnstileApi).not.toHaveBeenCalled();
  });

  it("propagates an unavailable API response", async () => {
    vi.mocked(waitForTurnstileApi).mockRejectedValueOnce(new Error("Check failed"));

    await expect(solveInvisibleTurnstile("site-key", "Check failed", null)).rejects.toThrow(
      "Check failed",
    );
    expect(rendered).toHaveLength(0);
  });

  it("rejects when Turnstile calls its error callback", async () => {
    const promise = solveInvisibleTurnstile("site-key", "Check failed", null);
    await vi.waitFor(() => expect(rendered).toHaveLength(1));
    const widget = present(rendered.at(0), "the rendered Turnstile widget");
    present(widget.options["error-callback"], "the Turnstile error callback")("code");

    await expect(promise).rejects.toThrow("Check failed");
  });

  it.each(["expired-callback", "timeout-callback", "unsupported-callback"] as const)(
    "rejects when Turnstile calls its %s",
    async (callback) => {
      const promise = solveInvisibleTurnstile("site-key", "Check failed", null);
      await vi.waitFor(() => expect(rendered).toHaveLength(1));
      const widget = present(rendered.at(0), "the rendered Turnstile widget");
      widget.options[callback]?.();

      await expect(promise).rejects.toThrow("Check failed");
    },
  );

  it("converts a render exception to the visitor-facing failure", async () => {
    turnstile.render = vi.fn(() => {
      throw new Error("provider internals");
    });
    const errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    const promise = solveInvisibleTurnstile("site-key", "Check failed", null);

    await expect(promise).rejects.toThrow("Check failed");
    expect(errorSpy).toHaveBeenCalledWith("Turnstile token request failed:", expect.any(Error));
    errorSpy.mockRestore();
  });
});
