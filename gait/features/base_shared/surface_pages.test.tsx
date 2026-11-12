import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

// Link is rendered as an anchor so page output remains assertable outside an Inertia app.
vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
}));

const { default: SurfaceDashboard } = await import("@/features/base/SurfaceDashboard");
const { default: WelcomeShow } = await import("@/features/self_service/WelcomeShow");
const { default: StandingShow } = await import("@/features/identity/StandingShow");
const { default: AppDashboardShow } = await import("@/pages/base/app/dashboards/show");
const { default: AppIdentityShow } = await import("@/pages/base/app/identities/show");
const { default: AppWelcomeShow } = await import("@/pages/base/app/welcomes/show");
const { default: AppStandingShow } = await import("@/pages/base/app/identity/standings/show");

describe("Base shared pages", () => {
  it("renders welcome navigation", () => {
    const markup = renderToStaticMarkup(
      <WelcomeShow
        title="Welcome!"
        next_link={{ label: "Next", href: "/dashboard?ri=jp" }}
      />,
    );

    expect(markup).toContain('href="/dashboard?ri=jp"');
  });

  it("uses the shared dashboard and identity renderers", () => {
    expect(AppDashboardShow).toBe(SurfaceDashboard);
    expect(AppIdentityShow).toBe(SurfaceDashboard);
    expect(AppWelcomeShow).toBe(WelcomeShow);
    expect(AppStandingShow).toBe(StandingShow);
  });
});
