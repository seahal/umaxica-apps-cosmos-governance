// The welcome screen a surface shows once, before handing over to its dashboard.
//
// Where "next" goes is a server decision: the welcome sequence resolves it and sends the finished
// destination, so the page never guesses the next step.
import ButtonLink from "@/components/ui/ButtonLink";
import Page from "@/components/ui/Page";

export type WelcomeShowProps = {
  title: string;
  next_link: { label: string; href: string };
};

export default function WelcomeShow({ title, next_link: nextLink }: WelcomeShowProps) {
  return (
    <Page title={title}>
      <p>
        <ButtonLink
          href={nextLink.href}
          inertia
        >
          {nextLink.label}
        </ButtonLink>
      </p>
    </Page>
  );
}
