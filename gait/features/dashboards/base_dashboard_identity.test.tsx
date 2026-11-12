import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import SurfaceDashboard, { type SurfaceDashboardProps } from "@/features/base/SurfaceDashboard";
import BaseAppDashboardsShow from "@/pages/base/app/dashboards/show";
import BaseOrgDashboardsShow from "@/pages/base/org/dashboards/show";

const props: SurfaceDashboardProps = {
  title: "Dashboard",
  sections: [
    {
      heading: "Menu links",
      current_identity: { display_name: "Selected Persona" },
      items: [
        { label: "Preference", href: "/preference?ri=jp" },
        { label: "Switcher", href: "/switcher?ri=jp" },
      ],
    },
  ],
};

describe("Base Dashboard identity navigation", () => {
  it("renders the selected Persona before Preference and Switcher", () => {
    const markup = renderToStaticMarkup(<SurfaceDashboard {...props} />);
    const identityIndex = markup.indexOf("Selected Persona");
    const preferenceIndex = markup.indexOf("Preference");
    const switcherIndex = markup.indexOf("Switcher");

    expect(identityIndex).toBeGreaterThanOrEqual(0);
    expect(identityIndex).toBeLessThan(preferenceIndex);
    expect(preferenceIndex).toBeLessThan(switcherIndex);
  });

  it("renders the server-supplied Avatar image before the Persona name", () => {
    const menu = props.sections[0]!;
    const withImage: SurfaceDashboardProps = {
      ...props,
      sections: [
        {
          ...menu,
          current_identity: {
            display_name: "Selected Persona",
            avatar_image: { src: "/dashboard/avatar_image?v=abc" },
          },
        },
      ],
    };
    const markup = renderToStaticMarkup(<SurfaceDashboard {...withImage} />);

    expect(markup).toContain('src="/dashboard/avatar_image?v=abc"');
    expect(markup.indexOf("<img")).toBeLessThan(markup.indexOf("Selected Persona"));
  });

  it("renders no image element when the identity has no Avatar image", () => {
    const markup = renderToStaticMarkup(<SurfaceDashboard {...props} />);

    expect(markup).not.toContain("<img");
    expect(markup).toContain("Selected Persona");
  });

  it("renders an unlinked grouped item for an identity without an image and omits empty items", () => {
    const markup = renderToStaticMarkup(
      <SurfaceDashboard
        title="Dashboard"
        sections={[
          {
            heading: "Available actions",
            current_identity: { display_name: "Unlinked persona", avatar_image: null },
            groups: [
              {
                heading: "Unavailable",
                items: [{ label: "Passkey setup", href: null }],
              },
            ],
            items: [],
          },
          { heading: "No active identity" },
        ]}
      />,
    );

    expect(markup).toContain("Unlinked persona");
    expect(markup).toContain("Passkey setup");
    expect(markup).not.toContain("<img");
    expect(markup).not.toContain('href="null"');
  });

  it("renders the optional dashboard description", () => {
    const markup = renderToStaticMarkup(
      <SurfaceDashboard
        title="Dashboard"
        description="Current identity settings."
        sections={[]}
      />,
    );

    expect(markup).toContain("Current identity settings.");
  });

  it.each([
    ["base/app", BaseAppDashboardsShow],
    ["base/org", BaseOrgDashboardsShow],
  ])("%s uses the shared Dashboard renderer", (_surface, Page) => {
    expect(Page).toBe(SurfaceDashboard);
  });
});
