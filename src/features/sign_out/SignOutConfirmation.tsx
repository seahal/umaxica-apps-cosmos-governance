import Button from "@/components/ui/Button";
import ButtonLink from "@/components/ui/ButtonLink";
import Page from "@/components/ui/Page";
import { csrfToken } from "@/lib/csrf";

type SignOutConfirmationForm = {
  action: string;
  submit: string;
  confirm_description: string;
};

type SignOutConfirmationProps = {
  title: string;
  active: boolean;
  description: string;
  form: SignOutConfirmationForm | null;
} & (
  | { back_link: { label: string; href: string }; home_link?: never }
  | { home_link: { label: string; href: string }; back_link?: never }
);

export default function SignOutConfirmation(props: SignOutConfirmationProps) {
  const { title, description, form } = props;
  const links: {
    back_link?: { label: string; href: string };
    home_link?: { label: string; href: string };
  } = props;
  if (links.back_link !== undefined && links.home_link !== undefined) {
    throw new Error("A sign-out page must provide one return link");
  }

  const returnLink = links.back_link ?? links.home_link;
  if (!returnLink) {
    throw new Error("A sign-out return link is required");
  }

  return (
    <Page
      title={title}
      description={description}
      width="narrow"
    >
      {form ? (
        <form
          action={form.action}
          method="post"
          data-turbo="false"
          className="flex flex-col gap-3"
        >
          <input
            type="hidden"
            name="authenticity_token"
            value={csrfToken()}
          />
          <div>
            <Button
              type="submit"
              variant="danger"
            >
              {form.submit}
            </Button>
          </div>
          <noscript>
            <p className="text-base text-fg-muted">{form.confirm_description}</p>
          </noscript>
        </form>
      ) : null}

      <p>
        <ButtonLink
          href={returnLink.href}
          variant="secondary"
          inertia
        >
          {returnLink.label}
        </ButtonLink>
      </p>
    </Page>
  );
}
