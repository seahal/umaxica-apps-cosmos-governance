import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";

type EmailRow = {
  public_id: string;
  address: string;
  status_label: string;
};

type Props = {
  title: string;
  empty_message: string;
  back_link: { label: string; href: string };
  table_headings: { address: string; status: string };
  emails: EmailRow[];
};

export default function EmailsIndex({
  title,
  empty_message: emptyMessage,
  back_link: backLink,
  table_headings: headings,
  emails,
}: Props) {
  return (
    <Page
      title={title}
      up={backLink}
      width="wide"
    >
      <Table label={title}>
        <thead>
          <tr>
            <th scope="col">{headings.address}</th>
            <th scope="col">{headings.status}</th>
          </tr>
        </thead>
        <tbody>
          {emails.map((email) => (
            <tr key={email.public_id}>
              <td>{email.address}</td>
              <td className="text-fg-muted">{email.status_label}</td>
            </tr>
          ))}
          {emails.length === 0 ? (
            <tr>
              <td
                colSpan={2}
                className="text-fg-muted italic"
              >
                {emptyMessage}
              </td>
            </tr>
          ) : null}
        </tbody>
      </Table>
    </Page>
  );
}
