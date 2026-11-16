import Card from "@/components/ui/Card";
import Page, { type PageUpLink } from "@/components/ui/Page";
// Base dashboard and identity hub sections are resolved by the owning controller.

export type DashboardItem = {
  label: string;
  href: string | null;
};

export type DashboardGroup = {
  heading: string;
  items: DashboardItem[];
};

export type DashboardSection = {
  heading: string;
  current_identity?: {
    display_name: string;
    /** Server-derived, same-origin image of the selected Avatar; absent when none exists. */
    avatar_image?: { src: string } | null;
  };
  items?: DashboardItem[];
  groups?: DashboardGroup[];
};

export type SurfaceDashboardProps = {
  title: string;
  description?: string;
  sections: DashboardSection[];
  /** Absent on the dashboard itself; identity and similar screens send the parent dashboard. */
  up_link?: PageUpLink | null;
};

function linkList(items: DashboardItem[]) {
  return (
    <ul className="flex flex-col gap-1">
      {items.map((item) => (
        <li
          key={item.label}
          className="text-base"
        >
          {item.href ? (
            <a
              href={item.href}
              className="ui-text-link text-fg underline underline-offset-4 hover:underline"
            >
              {item.label}
            </a>
          ) : (
            <span className="text-fg-muted">{item.label}</span>
          )}
        </li>
      ))}
    </ul>
  );
}

export default function SurfaceDashboard({
  title,
  description,
  sections,
  up_link: upLink = null,
}: SurfaceDashboardProps) {
  return (
    <Page
      title={title}
      {...(description ? { description } : {})}
      up={upLink}
      upVisit="inertia"
    >
      {sections.map((section) => (
        <Card
          key={section.heading}
          heading={section.heading}
        >
          {section.current_identity ? (
            <div className="mb-2 flex items-center gap-2">
              {section.current_identity.avatar_image ? (
                <img
                  src={section.current_identity.avatar_image.src}
                  alt=""
                  width={32}
                  height={32}
                  className="size-8 rounded-full object-cover"
                />
              ) : null}
              <p className="text-base font-medium text-fg">
                {section.current_identity.display_name}
              </p>
            </div>
          ) : null}
          {section.groups?.map((group) => (
            <div
              key={group.heading}
              className="flex flex-col gap-1"
            >
              <h3 className="text-base font-medium text-fg">{group.heading}</h3>
              {linkList(group.items)}
            </div>
          ))}
          {section.items && section.items.length > 0 ? linkList(section.items) : null}
        </Card>
      ))}
    </Page>
  );
}
