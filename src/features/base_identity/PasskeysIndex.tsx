import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";

type Row = {
  public_id: string;
  description: string;
  created_at: string | null;
  last_used_at: string | null;
  show_href: string;
};

type Props = {
  title: string;
  description: string;
  back_link: { label: string; href: string };
  empty_message: string;
  passkeys: Row[];
};

export default function PasskeysIndex({
  title,
  description,
  back_link: backLink,
  empty_message: emptyMessage,
  passkeys,
}: Props) {
  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      width="wide"
    >
      <ul className="flex flex-col gap-4">
        {passkeys.map((passkey) => (
          <li
            key={passkey.public_id}
            className="flex items-center justify-between gap-4"
          >
            <TextLink href={passkey.show_href}>{passkey.description}</TextLink>
          </li>
        ))}
        {passkeys.length === 0 ? <li>{emptyMessage}</li> : null}
      </ul>
    </Page>
  );
}
