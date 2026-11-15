import type { ComponentProps } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import SignOutConfirmation from "@/features/sign_out/SignOutConfirmation";

describe("Base App sign-out confirmation", () => {
  it("renders a CSRF-protected sign-out form and the Base App return link", () => {
    const csrf = document.createElement("meta");
    csrf.name = "csrf-token";
    csrf.content = "test-csrf-token";
    document.head.append(csrf);

    const markup = renderToStaticMarkup(
      <SignOutConfirmation
        active={true}
        title="Sign out?"
        description="Confirm that you want to sign out."
        form={{
          action: "/sign/out?ri=ww",
          submit: "Sign out",
          confirm_description: "Sign out from this browser.",
        }}
        back_link={{ label: "Return", href: "/?ri=ww" }}
      />,
    );
    csrf.remove();

    expect(markup).toMatch(/<form\b[^>]*action="\/sign\/out\?ri=ww"[^>]*>/u);
    expect(markup).toMatch(/<form\b[^>]*method="post"[^>]*>/u);
    expect(markup).toContain('data-turbo="false"');
    expect(markup).toContain('name="authenticity_token" value="test-csrf-token"');
    expect(markup).toContain("Sign out from this browser.");
    expect(markup).toMatch(/<a\b[^>]*href="\/\?ri=ww"[^>]*>Return<\/a>/u);
  });

  it("renders an informational page without a form and returns to the supplied home link", () => {
    const markup = renderToStaticMarkup(
      <SignOutConfirmation
        active={false}
        title="Already signed out"
        description="There is no active session."
        form={null}
        home_link={{ label: "Home", href: "/?ri=ww" }}
      />,
    );

    expect(markup).not.toContain("<form");
    expect(markup).toContain("There is no active session.");
    expect(markup).toMatch(/<a\b[^>]*href="\/\?ri=ww"[^>]*>Home<\/a>/u);
  });

  it("rejects a page with both return-link choices", () => {
    expect(() =>
      renderToStaticMarkup(
        (
          <SignOutConfirmation
            active={false}
            title="Sign out"
            description="Choose where to return."
            form={null}
            back_link={{ label: "Return", href: "/return" }}
            home_link={{ label: "Home", href: "/" }}
          />
        ) as ComponentProps<typeof SignOutConfirmation>,
      ),
    ).toThrow("A sign-out page must provide one return link");
  });

  it("rejects a page without a return link", () => {
    expect(() =>
      renderToStaticMarkup(
        (
          <SignOutConfirmation
            active={false}
            title="Sign out"
            description="Choose where to return."
            form={null}
          />
        ) as ComponentProps<typeof SignOutConfirmation>,
      ),
    ).toThrow("A sign-out return link is required");
  });
});
