import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, describe, expect, it, vi } from "vitest";

import { answerConfirmation } from "../../../../support/confirmation";
import { present } from "../../../../support/present";

// These tests mount the identity pages and fire real DOM events, so the submit and confirm
// branches the static markup cannot reach are covered.
const get = vi.fn();
const post = vi.fn();
const patch = vi.fn();
const destroy = vi.fn();

vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { get, post, patch, delete: destroy },
  usePage: () => ({ props: { errors: {} } }),
}));

// The challenge answers immediately so the submitted payload carries the issued token.
vi.mock("@/lib/turnstile", () => ({
  waitForTurnstileApi: () =>
    Promise.resolve({
      render: (_element: HTMLElement, options: { callback: (token: string) => void }) => {
        options.callback("tok_turnstile");
        return "widget";
      },
      execute: () => {},
      remove: () => {},
    }),
}));

const { default: PrivacyErasureNew } =
  await import("@/pages/base/app/identity/privacy/erasures/new");
const { default: WithdrawalSessionNew } =
  await import("@/pages/base/app/identity/withdrawal/sessions/new");
const { default: WithdrawalNew } = await import("@/pages/base/app/identity/withdrawals/new");
const { default: WithdrawalEdit } = await import("@/pages/base/app/identity/withdrawals/edit");

let container: HTMLDivElement;
let root: Root;

const mount = (element: React.ReactElement) => {
  container = document.createElement("div");
  document.body.append(container);
  root = createRoot(container);
  act(() => {
    root.render(element);
  });
};

// The widget loads the Turnstile API asynchronously; settle it before submitting.
const submitForm = (index = 0) => {
  const form = present(container.querySelectorAll("form")[index], `form ${index}`);
  act(() => {
    form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
  });
};

const clickButton = (label: string) => {
  const button = [...container.querySelectorAll("button")].find(
    (candidate) => candidate.textContent === label,
  );
  act(() => {
    button?.dispatchEvent(new MouseEvent("click", { bubbles: true }));
  });
};

// The confirmation is a rendered dialog now: its cancel button is first and its confirm button
// second, so answering it is a click rather than a stubbed `window.confirm`.

const setInput = (selector: string, value: string) => {
  const input = container.querySelector<HTMLInputElement>(selector);
  if (!input) {
    throw new Error(`no input for ${selector}`);
  }
  act(() => {
    const descriptor = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value");
    descriptor?.set?.call(input, value);
    input.dispatchEvent(new Event("input", { bubbles: true }));
  });
};

const toggleCheckbox = (selector: string) => {
  const input = container.querySelector<HTMLInputElement>(selector);
  if (!input) {
    throw new Error(`no checkbox for ${selector}`);
  }
  act(() => {
    input.click();
  });
};

afterEach(() => {
  act(() => {
    root.unmount();
  });
  container.remove();
  get.mockClear();
  post.mockClear();
  patch.mockClear();
  destroy.mockClear();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

describe("privacy erasure interaction", () => {
  it("does not submit an unavailable erasure request", () => {
    mount(
      <PrivacyErasureNew
        title="Early personal data erasure"
        notices={["Requests cannot be submitted here at this time."]}
        form={{
          action: "/identity/privacy/erasure",
          jurisdiction: "unknown",
          submit_label: "Unavailable",
        }}
      />,
    );
    expect(present(container.querySelector("button"), "unavailable button").disabled).toBe(true);
    expect(container.querySelector("form")).toBeNull();
    clickButton("Unavailable");
    expect(post).not.toHaveBeenCalled();
  });
});

describe("withdrawal interaction", () => {
  it("posts the re-entry address and the code", () => {
    mount(
      <WithdrawalSessionNew
        title="Withdrawal session"
        description="A code will be sent."
        address_form={{
          action: "/identity/withdrawal/session",
          label: "Email address",
          address: "",
          submit_label: "Send verification code",
        }}
        pass_code_form={{
          action: "/identity/withdrawal/session",
          label: "Verification code",
          submit_label: "Continue",
        }}
      />,
    );

    setInput("#withdrawal_reentry_address", "someone@example.com");
    submitForm(0);
    expect(post).toHaveBeenCalledWith("/identity/withdrawal/session", {
      withdrawal_reentry: { address: "someone@example.com" },
    });

    setInput("#withdrawal_pass_code", "123456");
    submitForm(1);
    expect(post).toHaveBeenCalledWith("/identity/withdrawal/session", {
      pass_code: "123456",
    });
  });

  it("submits the schedule step and the deactivation step", () => {
    mount(
      <WithdrawalNew
        title="Withdrawal"
        already_deactivated={false}
        already_deactivated_message="Already deactivated."
        recovery_link={{ label: "Recovery", href: "/identity/withdrawal/edit" }}
        schedule={{
          title: "Schedule withdrawal",
          ack_label: "I understand",
          submit_label: "Continue",
          acknowledged: false,
          action: "/identity/withdrawal",
          errors: [],
        }}
        deactivate={{
          title: "Deactivate today",
          ack_label: "I understand",
          submit_label: "Deactivate",
          confirm: "Sure?",
          action: "/identity/withdrawal",
          errors: [],
        }}
      />,
    );

    submitForm(0);
    expect(get).toHaveBeenCalledWith("/identity/withdrawal", { ack_schedule_purge: "0" });
    get.mockClear();

    toggleCheckbox("#ack_schedule_purge");
    submitForm(0);
    expect(get).toHaveBeenCalledWith("/identity/withdrawal", { ack_schedule_purge: "1" });

    submitForm(1);
    answerConfirmation(false);
    expect(patch).not.toHaveBeenCalled();

    submitForm(1);
    answerConfirmation(true);
    expect(patch).toHaveBeenCalledWith("/identity/withdrawal", {
      ack_deactivate_today: "0",
    });
    patch.mockClear();
    toggleCheckbox("#ack_deactivate_today");
    submitForm(1);
    answerConfirmation(true);
    expect(patch).toHaveBeenCalledWith("/identity/withdrawal", {
      ack_deactivate_today: "1",
    });
  });

  it("recovers and terminates only after confirmation", () => {
    mount(
      <WithdrawalEdit
        title="Withdrawal status"
        terminated={false}
        unavailable_message="Recovery is unavailable."
        deadline_message="Recoverable until 1 February 2026."
        recovery={{
          available_message: "Recovery is available.",
          submit_label: "Recover",
          confirm: "Sure?",
          action: "/identity/withdrawal",
          unavailable_message: null,
        }}
        termination={{
          submit_label: "Terminate now",
          confirm: "Sure?",
          action: "/identity/withdrawal",
          available_at_message: null,
        }}
        erasure_link={{ label: "Request early erasure", href: "/identity/privacy/erasure/new" }}
        sign_out={{ label: "Sign out", url: "/identity/withdrawal/session" }}
      />,
    );

    clickButton("Recover");
    answerConfirmation(false);
    clickButton("Terminate now");
    answerConfirmation(false);
    expect(post).not.toHaveBeenCalled();
    expect(destroy).not.toHaveBeenCalled();

    clickButton("Recover");
    answerConfirmation(true);
    expect(post).toHaveBeenCalledWith("/identity/withdrawal");

    clickButton("Terminate now");
    answerConfirmation(true);
    expect(destroy).toHaveBeenCalledWith("/identity/withdrawal");

    clickButton("Sign out");
    expect(destroy).toHaveBeenCalledWith("/identity/withdrawal/session");
  });

  it("renders without a termination section when the server sent none", () => {
    mount(
      <WithdrawalEdit
        title="Withdrawal status"
        terminated={false}
        unavailable_message="Recovery is unavailable."
        deadline_message="Recoverable until 1 February 2026."
        recovery={{
          available_message: "Recovery is available.",
          submit_label: "Recover",
          confirm: "Sure?",
          action: "/identity/withdrawal",
          unavailable_message: null,
        }}
        termination={null}
        erasure_link={{ label: "Request early erasure", href: "/identity/privacy/erasure/new" }}
        sign_out={{ label: "Sign out", url: "/identity/withdrawal/session" }}
      />,
    );

    expect(container.textContent).toContain("Recover");
    expect(container.textContent).not.toContain("Terminate now");
  });

  it("signs out from the terminated status", () => {
    mount(
      <WithdrawalEdit
        title="Withdrawal status"
        terminated
        unavailable_message="Recovery is unavailable."
        deadline_message={null}
        recovery={null}
        termination={null}
        erasure_link={{ label: "Request early erasure", href: "/identity/privacy/erasure/new" }}
        sign_out={{ label: "Sign out", url: "/identity/withdrawal/session" }}
      />,
    );

    clickButton("Sign out");
    expect(destroy).toHaveBeenCalledWith("/identity/withdrawal/session");
  });

  it("recovers without a confirmation when the server sent none", () => {
    mount(
      <WithdrawalEdit
        title="Withdrawal status"
        terminated={false}
        unavailable_message="Recovery is unavailable."
        deadline_message={null}
        recovery={{
          available_message: null,
          submit_label: "Recover",
          confirm: null,
          action: "/identity/withdrawal",
          unavailable_message: "Not now.",
        }}
        termination={{
          submit_label: "Terminate now",
          confirm: null,
          action: "/identity/withdrawal",
          available_at_message: "Available later.",
        }}
        erasure_link={{ label: "Request early erasure", href: "/identity/privacy/erasure/new" }}
        sign_out={{ label: "Sign out", url: "/identity/withdrawal/session" }}
      />,
    );

    expect(container.textContent).toContain("Not now.");
    expect(container.textContent).toContain("Available later.");
    clickButton("Recover");
    expect(post).toHaveBeenCalledWith("/identity/withdrawal");
    clickButton("Terminate now");
    expect(destroy).toHaveBeenCalledWith("/identity/withdrawal");
  });
});
