import Page from "@/components/ui/Page";

type Props = {
  title: string;
  description: string;
  back_link: { label: string; href: string };
  totp: { public_id: string; title: string | null; last_otp_at: string; status: string };
};

export default function TotpShow({ title, description, back_link: backLink, totp }: Props) {
  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      width="narrow"
    >
      <dl className="flex flex-col gap-2 text-base">
        <div className="flex flex-wrap gap-2">
          <dt className="font-medium">Reference</dt>
          <dd>{totp.public_id}</dd>
        </div>
        <div className="flex flex-wrap gap-2">
          <dt className="font-medium">Name</dt>
          <dd>{totp.title ?? "-"}</dd>
        </div>
        <div className="flex flex-wrap gap-2">
          <dt className="font-medium">Status</dt>
          <dd>{totp.status}</dd>
        </div>
        <div className="flex flex-wrap gap-2">
          <dt className="font-medium">Last used</dt>
          <dd>{totp.last_otp_at}</dd>
        </div>
      </dl>
    </Page>
  );
}
