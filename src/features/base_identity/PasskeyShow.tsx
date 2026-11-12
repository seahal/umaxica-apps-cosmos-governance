import Page from "@/components/ui/Page";

type Props = {
  title: string;
  description: string;
  back_link: { label: string; href: string };
  passkey: {
    description: string;
    description_label: string;
    created_at: string | null;
    last_used_at: string | null;
  };
};

export default function PasskeyShow({ title, description, back_link: backLink, passkey }: Props) {
  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      width="narrow"
    >
      <dl className="flex flex-col gap-2 text-base">
        <div className="flex flex-wrap gap-2">
          <dt className="font-medium">{passkey.description_label}</dt>
          <dd>{passkey.description}</dd>
        </div>
        <div className="flex flex-wrap gap-2">
          <dt className="font-medium">Created</dt>
          <dd>{passkey.created_at ?? "-"}</dd>
        </div>
        <div className="flex flex-wrap gap-2">
          <dt className="font-medium">Last used</dt>
          <dd>{passkey.last_used_at ?? "-"}</dd>
        </div>
      </dl>
    </Page>
  );
}
