import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

// The identity pages submit through `router` and render `Link`, neither of which exists outside a
// booted Inertia application. `Link` is stubbed to the anchor it renders so the static markup stays
// assertable.
vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { get: vi.fn(), post: vi.fn(), patch: vi.fn(), delete: vi.fn() },
  usePage: () => ({ props: { errors: {} } }),
}));

const { default: ActivitiesIndex } = await import("@/pages/base/app/identity/activities/index");
const { default: BirthdateShow } = await import("@/pages/base/app/identity/birthdates/show");
const { default: EmailsIndex } = await import("@/pages/base/app/identity/emails/index");
const { default: PrivacyErasureNew } =
  await import("@/pages/base/app/identity/privacy/erasures/new");
const { default: PrivacyErasureStatusShow } =
  await import("@/pages/base/app/identity/privacy/erasure/statuses/show");
const { default: TelephonesIndex } = await import("@/pages/base/app/identity/telephones/index");
const { default: WithdrawalSessionNew } =
  await import("@/pages/base/app/identity/withdrawal/sessions/new");
const { default: WithdrawalNew } = await import("@/pages/base/app/identity/withdrawals/new");
const { default: WithdrawalEdit } = await import("@/pages/base/app/identity/withdrawals/edit");

const backLink = { label: "Back", href: "/identity" };

describe("identity activities index", () => {
  const headings = {
    occurred_at: "Occurred at",
    activity: "Activity",
    device: "Device",
    source: "Source",
    risk: "Risk",
  };

  it("renders one row per activity", () => {
    const html = renderToStaticMarkup(
      <ActivitiesIndex
        title="Activity"
        description="Recent activity."
        empty_message="No activity."
        back_link={backLink}
        columns={headings}
        activities={[
          {
            occurred_at: "1 January 2026",
            activity: "Email updated",
            device: "Firefox / Linux",
            source: "Location unavailable",
            risk: "Low",
            risk_rank: 1,
          },
        ]}
      />,
    );

    expect(html).toContain("Email updated");
    expect(html).toContain("Firefox / Linux");
    expect(html).not.toContain("203.0.113.4");
    expect(html).not.toContain("{}");
    expect(html).not.toContain("No activity.");
  });

  it("renders the empty message with no activity", () => {
    const html = renderToStaticMarkup(
      <ActivitiesIndex
        title="Activity"
        description="Recent activity."
        empty_message="No activity."
        back_link={backLink}
        columns={headings}
        activities={[]}
      />,
    );

    expect(html).toContain("No activity.");
    expect(html).not.toContain("<table>");
  });
});

describe("identity birthdate show", () => {
  const base = {
    title: "Birthdate",
    description: "Your birthdate.",
    change_unavailable: "It cannot be changed.",
    birthdate_label: "Birthdate",
    not_set_label: "Not set",
    back_link: backLink,
  };

  it("renders the stored birthdate", () => {
    const html = renderToStaticMarkup(
      <BirthdateShow
        {...base}
        birthdate="2000-01-01"
      />,
    );

    expect(html).toContain("2000-01-01");
    expect(html).not.toContain("Not set");
  });

  it("renders the placeholder when no birthdate is stored", () => {
    const html = renderToStaticMarkup(
      <BirthdateShow
        {...base}
        birthdate={null}
      />,
    );

    expect(html).toContain("Not set");
  });
});

describe("identity emails index", () => {
  const shared = {
    title: "Emails",
    empty_message: "No email addresses.",
    back_link: backLink,
    table_headings: { address: "Address", status: "Status" },
  };

  it("lists the addresses", () => {
    const html = renderToStaticMarkup(
      <EmailsIndex
        {...shared}
        emails={[
          {
            public_id: "eml_1",
            address: "someone@example.com",
            status_label: "Verified",
          },
        ]}
      />,
    );

    expect(html).toContain("someone@example.com");
    expect(html).toContain("Verified");
    expect(html).not.toContain("No email addresses.");
  });

  it("renders the empty row", () => {
    const html = renderToStaticMarkup(
      <EmailsIndex
        {...shared}
        emails={[]}
      />,
    );

    expect(html).toContain("No email addresses.");
  });
});

describe("identity privacy erasure screens", () => {
  it("shows that the request is unavailable", () => {
    const html = renderToStaticMarkup(
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

    expect(html).toContain("Requests cannot be submitted here at this time.");
    expect(html).toContain("Unavailable");
    expect(html).toContain("disabled");
  });

  it("renders an active request", () => {
    const html = renderToStaticMarkup(
      <PrivacyErasureStatusShow
        title="Privacy erasure status"
        empty_message="No privacy erasure request is active."
        privacy_request={{
          status_label: "Status: received",
          received_label: "Received: 2026-01-01",
          response_due_label: "Response due: 2026-02-01",
        }}
      />,
    );

    expect(html).toContain("Status: received");
    expect(html).not.toContain("No privacy erasure request is active.");
  });

  it("renders the empty status", () => {
    const html = renderToStaticMarkup(
      <PrivacyErasureStatusShow
        title="Privacy erasure status"
        empty_message="No privacy erasure request is active."
        privacy_request={null}
      />,
    );

    expect(html).toContain("No privacy erasure request is active.");
  });
});

describe("identity telephone screens", () => {
  const headings = { number: "Number", status: "Status" };

  it("lists the telephones", () => {
    const html = renderToStaticMarkup(
      <TelephonesIndex
        title="Telephones"
        empty_message="No telephone numbers."
        back_link={backLink}
        table_headings={headings}
        telephones={[
          {
            public_id: "tel_1",
            number: "+819012345678",
            status_label: "Verified",
          },
        ]}
      />,
    );

    expect(html).toContain("+819012345678");
    expect(html).toContain("Verified");
  });

  it("renders the empty telephone row", () => {
    const html = renderToStaticMarkup(
      <TelephonesIndex
        title="Telephones"
        empty_message="No telephone numbers."
        back_link={backLink}
        table_headings={headings}
        telephones={[]}
      />,
    );

    expect(html).toContain("No telephone numbers.");
  });
});

describe("identity withdrawal screens", () => {
  it("renders the withdrawal re-entry screen with both forms", () => {
    const html = renderToStaticMarkup(
      <WithdrawalSessionNew
        title="Withdrawal session"
        description="A code will be sent."
        address_form={{
          action: "/identity/withdrawal/session",
          label: "Email address",
          address: "someone@example.com",
          submit_label: "Send verification code",
        }}
        pass_code_form={{
          action: "/identity/withdrawal/session",
          label: "Verification code",
          submit_label: "Continue",
        }}
      />,
    );

    expect(html).toContain("Verification code");
  });

  it("renders the withdrawal re-entry screen without the code form", () => {
    const html = renderToStaticMarkup(
      <WithdrawalSessionNew
        title="Withdrawal session"
        description="A code will be sent."
        address_form={{
          action: "/identity/withdrawal/session",
          label: "Email address",
          address: "",
          submit_label: "Send verification code",
        }}
        pass_code_form={null}
      />,
    );

    expect(html).not.toContain("Verification code");
  });

  const schedule = {
    title: "Schedule withdrawal",
    ack_label: "I understand",
    submit_label: "Continue",
    acknowledged: false,
    action: "/identity/withdrawal",
    errors: [] as string[],
  };

  it("renders the schedule step alone", () => {
    const html = renderToStaticMarkup(
      <WithdrawalNew
        title="Withdrawal"
        already_deactivated={false}
        already_deactivated_message="Already deactivated."
        recovery_link={{ label: "Recovery", href: "/identity/withdrawal/edit" }}
        schedule={schedule}
        deactivate={null}
      />,
    );

    expect(html).toContain("Schedule withdrawal");
    expect(html).not.toContain("Deactivate today");
  });

  it("renders both steps and their errors", () => {
    const html = renderToStaticMarkup(
      <WithdrawalNew
        title="Withdrawal"
        already_deactivated={false}
        already_deactivated_message="Already deactivated."
        recovery_link={{ label: "Recovery", href: "/identity/withdrawal/edit" }}
        schedule={{ ...schedule, acknowledged: true, errors: ["Acknowledgement is required"] }}
        deactivate={{
          title: "Deactivate today",
          ack_label: "I understand",
          submit_label: "Deactivate",
          confirm: "Sure?",
          action: "/identity/withdrawal",
          errors: ["Acknowledgement is required"],
        }}
      />,
    );

    expect(html).toContain("Deactivate today");
    expect(html).toContain("Acknowledgement is required");
  });

  it("renders the deactivated notice instead of the steps", () => {
    const html = renderToStaticMarkup(
      <WithdrawalNew
        title="Withdrawal"
        already_deactivated
        already_deactivated_message="Already deactivated."
        recovery_link={{ label: "Recovery", href: "/identity/withdrawal/edit" }}
        schedule={schedule}
        deactivate={null}
      />,
    );

    expect(html).toContain("Already deactivated.");
    expect(html).not.toContain("Schedule withdrawal");
  });

  const signOut = { label: "Sign out", url: "/identity/withdrawal/session" };
  const erasureLink = { label: "Request early erasure", href: "/identity/privacy/erasure/new" };

  it("renders the recoverable status", () => {
    const html = renderToStaticMarkup(
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
        erasure_link={erasureLink}
        sign_out={signOut}
      />,
    );

    expect(html).toContain("Recovery is available.");
    expect(html).toContain("Terminate now");
  });

  it("renders the pending status", () => {
    const html = renderToStaticMarkup(
      <WithdrawalEdit
        title="Withdrawal status"
        terminated={false}
        unavailable_message="Recovery is unavailable."
        deadline_message="Recoverable until 1 February 2026."
        recovery={{
          available_message: null,
          submit_label: null,
          confirm: null,
          action: null,
          unavailable_message: "Recovery is unavailable.",
        }}
        termination={{
          submit_label: null,
          confirm: null,
          action: null,
          available_at_message: "Termination becomes available on 1 February 2026.",
        }}
        erasure_link={erasureLink}
        sign_out={signOut}
      />,
    );

    expect(html).toContain("Termination becomes available on 1 February 2026.");
    expect(html).not.toContain("Terminate now");
  });

  it("renders termination without a recovery section", () => {
    const html = renderToStaticMarkup(
      <WithdrawalEdit
        title="Withdrawal status"
        terminated={false}
        unavailable_message="Recovery is unavailable."
        deadline_message={null}
        recovery={null}
        termination={{
          submit_label: "Terminate now",
          confirm: "Sure?",
          action: "/identity/withdrawal",
          available_at_message: null,
        }}
        erasure_link={erasureLink}
        sign_out={signOut}
      />,
    );

    expect(html).toContain("Terminate now");
    expect(html).not.toContain("Recover");
  });

  it("renders the terminated status", () => {
    const html = renderToStaticMarkup(
      <WithdrawalEdit
        title="Withdrawal status"
        terminated
        unavailable_message="Recovery is unavailable."
        deadline_message={null}
        recovery={null}
        termination={null}
        erasure_link={erasureLink}
        sign_out={signOut}
      />,
    );

    expect(html).toContain("Recovery is unavailable.");
    expect(html).not.toContain("Request early erasure");
  });
});
