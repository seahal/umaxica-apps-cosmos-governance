// The identifier list of a self-service identity screen (email addresses, telephone numbers).
//
// Column headings, the verification wording and every destination arrive resolved from the server,
// so the table renders the payload without deciding anything about it.
import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";

export type CredentialEntry = {
  public_id: string;
  value: string;
  status: string;
};

export type CredentialIndexProps = {
  title: string;
  back_link: { label: string; href: string };
  columns: { value: string; status: string };
  empty_message: string;
  entries: CredentialEntry[];
};

export default function CredentialIndex({
  title,
  back_link: backLink,
  columns,
  empty_message: emptyMessage,
  entries,
}: CredentialIndexProps) {
  return (
    <Page
      title={title}
      up={backLink}
      upVisit="inertia"
      width="wide"
    >
      <Table label={title}>
        <thead>
          <tr>
            <th scope="col">{columns.value}</th>
            <th scope="col">{columns.status}</th>
          </tr>
        </thead>
        <tbody>
          {entries.map((entry) => (
            <tr key={entry.public_id}>
              <td>{entry.value}</td>
              <td>
                <span className="text-fg-muted">{entry.status}</span>
              </td>
            </tr>
          ))}
          {entries.length === 0 ? (
            <tr>
              <td colSpan={2}>{emptyMessage}</td>
            </tr>
          ) : null}
        </tbody>
      </Table>
    </Page>
  );
}
