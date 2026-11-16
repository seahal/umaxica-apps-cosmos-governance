import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
}));

const { default: PasskeyShow } = await import("@/features/base_identity/PasskeyShow");
const { default: PasskeysIndex } = await import("@/features/base_identity/PasskeysIndex");
const { default: TotpShow } = await import("@/features/base_identity/TotpShow");
const { default: TotpsIndex } = await import("@/features/base_identity/TotpsIndex");

const backLink = { label: "Back", href: "/identity" };

describe("Base passkey identity screens", () => {
  it("shows recorded credential details and an explicit placeholder for missing dates", () => {
    const markup = renderToStaticMarkup(
      <PasskeyShow
        title="Passkey"
        description="Credential details"
        back_link={backLink}
        passkey={{
          description: "Laptop",
          description_label: "Name",
          created_at: "2026-11-01",
          last_used_at: null,
        }}
      />,
    );

    expect(markup).toContain("Laptop");
    expect(markup).toContain("2026-11-01");
    expect(markup).toContain("Last used");
    expect(markup).toContain(">-</dd>");
  });

  it("shows a placeholder when the passkey has no creation timestamp", () => {
    const markup = renderToStaticMarkup(
      <PasskeyShow
        title="Passkey"
        description="Credential details"
        back_link={backLink}
        passkey={{
          description: "Security key",
          description_label: "Name",
          created_at: null,
          last_used_at: "2026-11-10",
        }}
      />,
    );

    expect(markup).toContain("Security key");
    expect(markup).toContain("2026-11-10");
    expect(markup).toContain("Created</dt><dd>-</dd>");
  });

  it("lists passkeys and reports an empty inventory", () => {
    const populated = renderToStaticMarkup(
      <PasskeysIndex
        title="Passkeys"
        description="Registered credentials"
        back_link={backLink}
        empty_message="No passkeys."
        passkeys={[
          {
            public_id: "pky_one",
            description: "Work laptop",
            created_at: "2026-11-01",
            last_used_at: "2026-11-10",
            show_href: "/identity/passkeys/pky_one",
          },
        ]}
      />,
    );
    const empty = renderToStaticMarkup(
      <PasskeysIndex
        title="Passkeys"
        description="Registered credentials"
        back_link={backLink}
        empty_message="No passkeys."
        passkeys={[]}
      />,
    );

    expect(populated).toContain('href="/identity/passkeys/pky_one"');
    expect(populated).toContain("Work laptop");
    expect(populated).not.toContain("No passkeys.");
    expect(empty).toContain("No passkeys.");
  });
});

describe("Base TOTP identity screens", () => {
  it("shows a named credential and uses a placeholder when it has no title", () => {
    const markup = renderToStaticMarkup(
      <TotpShow
        title="Authenticator"
        description="Authenticator details"
        back_link={backLink}
        totp={{ public_id: "tot_one", title: null, last_otp_at: "2026-11-11", status: "Active" }}
      />,
    );

    expect(markup).toContain("tot_one");
    expect(markup).toContain("Status");
    expect(markup).toContain("Active");
    expect(markup).toContain(">-</dd>");
  });

  it("lists TOTP credentials and reports an empty inventory", () => {
    const populated = renderToStaticMarkup(
      <TotpsIndex
        title="Authenticators"
        description="Registered authenticators"
        back_link={backLink}
        columns={{ title: "Name", last_otp_at: "Last used", status: "Status" }}
        empty_message="No authenticators."
        totps={[
          {
            public_id: "tot_one",
            title: "Phone",
            last_otp_at: "2026-11-11",
            status: "Active",
            show_href: "/identity/totps/tot_one",
          },
        ]}
      />,
    );
    const empty = renderToStaticMarkup(
      <TotpsIndex
        title="Authenticators"
        description="Registered authenticators"
        back_link={backLink}
        columns={{ title: "Name", last_otp_at: "Last used", status: "Status" }}
        empty_message="No authenticators."
        totps={[]}
      />,
    );

    expect(populated).toContain('href="/identity/totps/tot_one"');
    expect(populated).toContain("Phone");
    expect(populated).toContain("2026-11-11");
    expect(empty).toContain("No authenticators.");
  });
});
