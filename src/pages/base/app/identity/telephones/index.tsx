import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";

type TelephoneRow = {
  public_id: string;
  number: string;
  status_label: string;
};

type Props = {
  title: string;
  empty_message: string;
  back_link: { label: string; href: string };
  table_headings: { number: string; status: string };
  telephones: TelephoneRow[];
};

export default function TelephonesIndex({
  title,
  empty_message: emptyMessage,
  back_link: backLink,
  table_headings: headings,
  telephones,
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
            <th scope="col">{headings.number}</th>
            <th scope="col">{headings.status}</th>
          </tr>
        </thead>
        <tbody>
          {telephones.map((telephone) => (
            <tr key={telephone.public_id}>
              <td>{telephone.number}</td>
              <td className="text-fg-muted">{telephone.status_label}</td>
            </tr>
          ))}
          {telephones.length === 0 ? (
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
