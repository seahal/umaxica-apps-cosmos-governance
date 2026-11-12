import { Link } from "@inertiajs/react";

import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";

type TotpRow = {
  public_id: string;
  title: string;
  last_otp_at: string;
  status: string;
  show_href: string;
};

type Props = {
  title: string;
  description: string;
  back_link: { label: string; href: string };
  columns: { title: string; last_otp_at: string; status: string };
  empty_message: string;
  totps: TotpRow[];
};

export default function TotpsIndex({
  title,
  description,
  back_link: backLink,
  columns,
  empty_message: emptyMessage,
  totps,
}: Props) {
  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      width="wide"
    >
      <Table label={title}>
        <thead>
          <tr>
            <th scope="col">{columns.title}</th>
            <th scope="col">{columns.last_otp_at}</th>
            <th scope="col">{columns.status}</th>
          </tr>
        </thead>
        <tbody>
          {totps.map((totp) => (
            <tr key={totp.public_id}>
              <td>
                <Link
                  href={totp.show_href}
                  className="ui-text-link text-base text-fg-muted underline underline-offset-4 hover:text-fg"
                >
                  {totp.title}
                </Link>
              </td>
              <td>{totp.last_otp_at}</td>
              <td>{totp.status}</td>
            </tr>
          ))}
          {totps.length === 0 ? (
            <tr>
              <td colSpan={3}>{emptyMessage}</td>
            </tr>
          ) : null}
        </tbody>
      </Table>
    </Page>
  );
}
