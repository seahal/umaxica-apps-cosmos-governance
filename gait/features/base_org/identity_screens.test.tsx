import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

// The base/org identity screens render server-resolved props. `Link` is stubbed to the anchor it
// produces so the static markup stays assertable outside a booted Inertia application, and the
// Turnstile API is stubbed because the challenge script never loads in a unit test.
vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
}));

vi.mock("@/lib/turnstile", () => ({
  waitForTurnstileApi: () =>
    Promise.resolve({ render: () => "widget", execute: () => {}, remove: () => {} }),
}));

const { default: CredentialIndex } = await import("@/pages/base/org/identity/emails/index");
const { default: EmailPreferenceEdit } = await import("@/pages/base/org/identity/emails/edit");
const { default: BirthdateShow } = await import("@/pages/base/org/identity/birthdates/show");
const { default: StandingShow } = await import("@/pages/base/org/identity/standings/show");
const { default: InfoPage } = await import("@/pages/base/org/identity/withdrawals/show");
const { default: SecretCredentialIndex } =
  await import("@/pages/base/org/identity/secret_credentials/index");
const { default: SecretCredentialShow } =
  await import("@/pages/base/org/identity/secret_credentials/show");
const { default: SecretCredentialForm } =
  await import("@/pages/base/org/identity/secret_credentials/new");
const { default: SelfServiceShell } = await import("@/pages/base/org/accounts/index");
const { default: WelcomeShow } = await import("@/pages/base/org/welcomes/show");
const { csrfToken } = await import("@/lib/csrf");

const turnstile = { site_key: "site", mode: "execute" as const, action: null, cdata: null };
const backLink = { label: "Back", href: "/identity" };

describe("credential index", () => {
  const props = {
    title: "Email",
    back_link: backLink,
    columns: { value: "Address", status: "Status" },
    empty_message: "No email addresses registered.",
    entries: [
      {
        public_id: "eml_1",
        value: "staff@example.test",
        status: "Verified",
      },
    ],
  };

  it("lists every identifier the server sent", () => {
    const markup = renderToStaticMarkup(<CredentialIndex {...props} />);

    expect(markup).toContain("staff@example.test");
    expect(markup).toContain("Verified");
    expect(markup).not.toContain('href="/identity/emails/eml_1/edit"');
    expect(markup).not.toContain("No email addresses registered.");
  });

  it("shows the empty row when there is nothing to list", () => {
    const markup = renderToStaticMarkup(
      <CredentialIndex
        {...props}
        entries={[]}
      />,
    );

    expect(markup).toContain("No email addresses registered.");
  });
});

describe("email preference edit", () => {
  const props = {
    title: "Email settings",
    address: "staff@example.test",
    form: {
      action: "/identity/emails/eml_1",
      scope: "staff_email",
      promotional: true,
      notifiable: false,
      always_on_label: "Important",
      always_on_description: "Always sent.",
      promotional_label: "Promotional",
      promotional_description: "Campaigns.",
      notifiable_label: "Notifications",
      notifiable_description: "Updates.",
      submit: "Save",
      turnstile,
    },
    delete: { label: "Delete", href: "/identity/emails/eml_1", confirm: "Delete?" },
    cancel_link: { label: "Cancel", href: "/identity/emails" },
    error_messages: ["Address is invalid"],
  };

  it("keeps the update a PATCH and the removal a DELETE", () => {
    const markup = renderToStaticMarkup(<EmailPreferenceEdit {...props} />);

    expect(markup).toContain('name="_method" value="patch"');
    expect(markup).toContain('name="_method" value="delete"');
    expect(markup).toContain('name="staff_email[promotional]" checked="" value="1"');
    expect(markup).toContain("Address is invalid");
  });
});

describe("read-only identity screens", () => {
  it("distinguishes a recorded birthdate from an unset one", () => {
    const props = {
      title: "Birthdate",
      description: "Recorded for this operator.",
      birthdate_label: "Birthdate",
      birthdate: "2000-01-01",
      not_set: "Not set",
      change_unavailable: "Contact an operator.",
      back_link: backLink,
    };

    expect(renderToStaticMarkup(<BirthdateShow {...props} />)).toContain("2000-01-01");
    expect(
      renderToStaticMarkup(
        <BirthdateShow
          {...props}
          birthdate={null}
        />,
      ),
    ).toContain("Not set");
  });

  it("renders each standing decision, with and without an end date", () => {
    const markup = renderToStaticMarkup(
      <StandingShow
        title="Account Standing"
        status_label="Current status: Good"
        decisions={[
          { public_id: "d1", kind: "Suspension", reason: "Abuse", ends_at: "Ends: 2026-01-01" },
          { public_id: "d2", kind: "Warning", reason: "Spam", ends_at: null },
        ]}
      />,
    );

    expect(markup).toContain('id="standing-decision-d1"');
    expect(markup).toContain("Ends: 2026-01-01");
    expect(markup).toContain("Warning");
  });

  it("renders an informational screen", () => {
    const markup = renderToStaticMarkup(
      <InfoPage
        title="Withdrawal"
        paragraphs={["Not self-service.", "Recorded as a request."]}
        back_link={backLink}
      />,
    );

    expect(markup).toContain("Not self-service.");
    expect(markup).toContain("Recorded as a request.");
  });
});

describe("secret credential screens", () => {
  it("lists credentials with a delete form each", () => {
    const markup = renderToStaticMarkup(
      <SecretCredentialIndex
        title="Secrets"
        description="Manage secrets."
        new_link={{ label: "New", href: "/identity/secrets/new" }}
        columns={{
          name: "Name",
          created_at: "Created",
          last_used_at: "Last used",
          actions: "Actions",
        }}
        edit_label="Edit"
        destroy_label="Delete"
        destroy_confirm="Sure?"
        turnstile={turnstile}
        secret_credentials={[
          {
            public_id: "sec_1",
            name: "abcd",
            created_at: "01/01",
            last_used_at: "-",
            edit_href: "/identity/secrets/sec_1/edit",
            destroy_href: "/identity/secrets/sec_1",
          },
        ]}
      />,
    );

    expect(markup).toContain('name="_method" value="delete"');
    expect(markup).toContain("/identity/secrets/sec_1/edit");
  });

  it("shows a credential's metadata", () => {
    const markup = renderToStaticMarkup(
      <SecretCredentialShow
        title="Secret"
        description="Details."
        name="abcd"
        created_at_label="Created"
        created_at="01 January"
        last_used_at_label="Last used"
        last_used_at="Never"
        back_link={{ label: "Back", href: "/identity/secrets" }}
        edit_link={{ label: "Edit", href: "/identity/secrets/sec_1/edit" }}
      />,
    );

    expect(markup).toContain("Never");
  });

  it("offers the secret field on creation and not on rename", () => {
    const form = {
      action: "/identity/secrets",
      scope: "staff_secret_credential",
      name: "abcd",
      name_label: "Name",
      submit: "Save",
    };

    const createMarkup = renderToStaticMarkup(
      <SecretCredentialForm
        title="New secret"
        description="Create one."
        form={{ ...form, value_label: "Value", confirm_saved_label: "I saved it" }}
        cancel_link={{ label: "Cancel", href: "/identity/secrets" }}
        turnstile={turnstile}
        error_header={null}
        error_messages={[]}
      />,
    );

    expect(createMarkup).toContain('name="staff_secret_credential[value]"');
    expect(createMarkup).toContain("I saved it");
    expect(createMarkup).not.toContain('name="_method"');

    const renameMarkup = renderToStaticMarkup(
      <SecretCredentialForm
        title="Edit secret"
        description="Rename it."
        form={{ ...form, method: "patch" }}
        cancel_link={{ label: "Cancel", href: "/identity/secrets" }}
        turnstile={turnstile}
        error_header="1 error prohibited this record from being saved"
        error_messages={["Name is invalid"]}
      />,
    );

    expect(renameMarkup).toContain('name="_method" value="patch"');
    expect(renameMarkup).not.toContain('name="staff_secret_credential[value]"');
    expect(renameMarkup).toContain("Name is invalid");
  });
});

describe("shared self-service screens", () => {
  it("renders the account shell and welcome page", () => {
    expect(
      renderToStaticMarkup(
        <SelfServiceShell
          title="Account"
          body="account"
        />,
      ),
    ).toContain("Signed in");

    expect(
      renderToStaticMarkup(
        <WelcomeShow
          title="Welcome!"
          next_link={{ label: "Next", href: "/dashboard" }}
        />,
      ),
    ).toContain('href="/dashboard"');
  });
});

describe("csrf token", () => {
  it("reads the meta tag, and falls back to an empty string when it is absent", () => {
    expect(csrfToken()).toBe("");

    const meta = document.createElement("meta");
    meta.name = "csrf-token";
    meta.content = "token-value";
    document.head.append(meta);

    expect(csrfToken()).toBe("token-value");

    meta.remove();
  });
});
