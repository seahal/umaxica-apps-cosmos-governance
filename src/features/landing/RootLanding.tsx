// The thin public landing every surface answers with at its root.
//
// It used to be a self-contained ERB document with its own inline stylesheet, one copy per surface.
// The surfaces differ only in their heading and description, so both arrive as props and the markup
// is shared.
export type RootLandingLink = {
  label: string;
  href: string;
};

export type RootLandingProps = {
  // A root document renders the brand alone, so a surface whose landing carries no page title of
  // its own sends null and the layout falls back to that contract.
  title: string | null;
  heading: string;
  description: string;
  // The server has already decided which public destinations the visitor may see.
  links?: RootLandingLink[] | null;
};

export default function RootLanding({ heading, description, links }: RootLandingProps) {
  const headingId = "root-landing-title";

  return (
    <section
      aria-labelledby={headingId}
      className="mx-auto flex w-full max-w-2xl flex-col gap-8"
    >
      <div className="flex w-full flex-col gap-6">
        <header className="flex flex-col gap-4">
          <h1
            id={headingId}
            className="min-w-0 wrap-anywhere text-3xl leading-snug font-semibold text-balance text-fg sm:text-4xl"
          >
            {heading}
          </h1>
          <p className="max-w-prose text-lg text-pretty text-fg-muted">{description}</p>
        </header>

        {links?.length ? (
          <nav aria-label="Navigation">
            <ul className="flex flex-wrap items-center gap-4">
              {links.map((link) => (
                <li key={link.href}>
                  <a
                    href={link.href}
                    className="ui-text-link text-base text-fg-muted underline underline-offset-4 hover:text-fg hover:underline"
                  >
                    {link.label}
                  </a>
                </li>
              ))}
            </ul>
          </nav>
        ) : null}
      </div>
    </section>
  );
}
