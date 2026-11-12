// @vitest-environment node

import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

const { page } = vi.hoisted(() => ({
  page: {
    props: {
      chrome: {
        surface: "app",
        brand: { name: "Umaxica", href: "https://umaxica.app/" },
        banner: null,
        footer_navigation: null,
        cookie_controls: null,
        theme_controls: null,
        copyright: "(c) Umaxica",
      },
      errors: {},
    },
  },
}));

vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { clearHistory: vi.fn() },
  useForm: (initial: Record<string, string>) => ({
    data: initial,
    setData: vi.fn(),
    errors: {},
    processing: false,
    transform: vi.fn(),
    post: vi.fn(),
  }),
  usePage: () => page,
}));

vi.mock("@/components/chrome/CookieBanner", () => ({ default: () => null }));
vi.mock("@/components/chrome/ThemeControls", () => ({ default: () => null }));

const { default: DocumentLocale } = await import("@/components/ui/DocumentLocale");
const { default: SurfaceLayout } = await import("@/layouts/SurfaceLayout");
const { default: AdminConfirmation } = await import("@/features/org_admin/AdminConfirmation");
const { default: AdminRecordList } = await import("@/features/org_admin/AdminRecordList");

describe("server rendering without a browser document", () => {
  it("renders the locale provider using React Aria's default locale detection", () => {
    const markup = renderToStaticMarkup(
      <DocumentLocale>
        <p>Server page</p>
      </DocumentLocale>,
    );

    expect(markup).toContain("Server page");
  });

  it("renders the surface chrome without looking up browser metadata", () => {
    const markup = renderToStaticMarkup(
      <SurfaceLayout>
        <p>Server page body</p>
      </SurfaceLayout>,
    );

    expect(markup).toContain("Server page body");
    expect(markup).toContain("Umaxica");
    expect(markup).toContain("(c) Umaxica");
  });

  it("renders an administrative list without browser pagination metadata", () => {
    const markup = renderToStaticMarkup(
      <AdminRecordList
        title="Clients"
        context={{
          operator_label: "Operator",
          operator_public_id: "operator_one",
          realm_label: null,
          realm: null,
        }}
        columns={["Public ID"]}
        rows={[]}
        empty_message="No clients."
        search={null}
        pagination={{ previous: null, next: null }}
        actions={[]}
      />,
    );

    expect(markup).toContain("No clients.");
    expect(markup).not.toContain("aria-label=");
  });

  it("renders an administrative confirmation without browser help metadata", () => {
    const markup = renderToStaticMarkup(
      <AdminConfirmation
        title="Confirm revocation"
        context={{
          operator_label: "Operator",
          operator_public_id: "operator_one",
          realm_label: null,
          realm: null,
        }}
        target={[]}
        effect="Sessions will be revoked."
        action="/support/revocations"
        fields={[]}
        acknowledgement="I checked the target."
        submit_label="Revoke"
      />,
    );

    expect(markup).toContain("Sessions will be revoked.");
    expect(markup).toContain("Revoke");
  });
});
