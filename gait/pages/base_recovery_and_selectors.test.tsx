import type { router as inertiaRouter } from "@inertiajs/react";
import { fireEvent, render, screen } from "@testing-library/react";
import { act } from "react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { present } from "../support/present";
import { finishVisit, startVisit } from "../support/visit";

const { patchRequest, postRequest } = vi.hoisted(() => ({
  patchRequest: vi.fn<typeof inertiaRouter.patch>(),
  postRequest: vi.fn<typeof inertiaRouter.post>(),
}));

vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { patch: patchRequest, post: postRequest },
}));

const { default: RecoveryShow } = await import("@/pages/base/app/identity/recoveries/show");
const { default: AppSelectorShow } = await import("@/pages/base/app/selectors/show");
const { default: OrgSelectorShow } = await import("@/pages/base/org/selectors/show");

afterEach(() => {
  patchRequest.mockClear();
  postRequest.mockClear();
});

describe("app recovery page", () => {
  it("renders restore and appeal actions and submits their server-owned payloads", () => {
    render(
      <RecoveryShow
        title="Recovery"
        description="Review enforcement decisions"
        appeal_error={null}
        enforcement_cases={[
          {
            public_id: "case_restore",
            kind_label: "Restore access",
            restore: { url: "/recovery/restore", submit_label: "Restore" },
            appeal: null,
          },
          {
            public_id: "case_appeal",
            kind_label: "Appeal suspension",
            restore: { url: "/recovery/appeal/restore", submit_label: "Restore appeal" },
            appeal: {
              url: "/recovery/appeals",
              reason_label: "Reason",
              reason_codes: [
                { label: "Mistake", value: "mistake" },
                { label: "New evidence", value: "new_evidence" },
              ],
              statement_label: "Statement",
              statement_max_length: 500,
              submit_label: "Submit appeal",
            },
          },
        ]}
      />,
    );

    fireEvent.submit(screen.getByRole("button", { name: "Restore" }).closest("form")!);
    expect(postRequest).toHaveBeenCalledWith("/recovery/restore", {
      data: { enforcement_case_id: "case_restore" },
    });

    fireEvent.change(screen.getByRole("combobox", { name: "Reason" }), {
      target: { value: "new_evidence" },
    });
    fireEvent.change(screen.getByRole("textbox", { name: "Statement" }), {
      target: { value: "The original evidence was incomplete." },
    });
    fireEvent.submit(screen.getByRole("button", { name: "Submit appeal" }).closest("form")!);

    const [appealUrl, appealData, appealVisit] = present(
      postRequest.mock.calls.at(-1),
      "appeal POST call",
    );
    expect(appealUrl).toBe("/recovery/appeals");
    expect(appealData).toEqual({
      appeal: {
        enforcement_case_id: "case_appeal",
        reason_code: "new_evidence",
        statement: "The original evidence was incomplete.",
      },
    });
    expect(appealVisit?.onStart).toBeTypeOf("function");
    expect(appealVisit?.onFinish).toBeTypeOf("function");
    const appealButton = screen.getByRole<HTMLButtonElement>("button", { name: "Submit appeal" });
    act(() => startVisit(appealVisit));
    expect(appealButton.disabled).toBe(true);
    act(() => finishVisit(appealVisit));
    expect(appealButton.disabled).toBe(false);
  });

  it("shows appeal errors and safely submits no action for a case without an appeal form", () => {
    render(
      <RecoveryShow
        title="Recovery"
        description="Review"
        appeal_error="Appeal could not be submitted."
        enforcement_cases={[
          {
            public_id: "case_one",
            kind_label: "Restricted",
            restore: { url: "/recovery/restore", submit_label: "Restore" },
            appeal: null,
          },
        ]}
      />,
    );

    expect(screen.getByText("Appeal could not be submitted.")).toBeTruthy();
    expect(screen.queryByRole("button", { name: "Submit appeal" })).toBeNull();
    fireEvent.submit(screen.getByRole("button", { name: "Restore" }).closest("form")!);
    expect(postRequest).toHaveBeenCalledTimes(1);
  });

  it("keeps the reason unselected when the server provides no appeal reason codes", () => {
    render(
      <RecoveryShow
        title="Recovery"
        description="Review"
        appeal_error={null}
        enforcement_cases={[
          {
            public_id: "case_one",
            kind_label: "Restricted",
            restore: { url: "/recovery/restore", submit_label: "Restore" },
            appeal: {
              url: "/recovery/appeals",
              reason_label: "Reason",
              reason_codes: [],
              statement_label: "Statement",
              statement_max_length: 500,
              submit_label: "Submit appeal",
            },
          },
        ]}
      />,
    );

    expect(screen.getByRole<HTMLSelectElement>("combobox", { name: "Reason" }).value).toBe("");
  });
});

const appSelectorProps = {
  title: "Choose identity",
  description: "Select a client persona",
  account_label: "Account",
  organization_label: "Organization",
  unit_label: "Unit",
  avatar_label: "Avatar",
  submit_label: "Continue",
  empty_message: "No identities are available.",
  action: "/identity/selection",
  error: "Selection expired.",
  candidates: [
    {
      account_public_id: "acc_one",
      organization_public_id: "org_one",
      organization_unit_public_id: "unit_one",
      avatar_public_id: "avt_one",
    },
  ],
};

const orgSelectorProps = {
  title: "Choose organization",
  description: "Select a workspace",
  account_label: "Account",
  organization_label: "Organization",
  unit_label: "Unit",
  submit_label: "Continue",
  empty_message: "No workspaces are available.",
  action: "/organization/selection",
  error: null,
  candidates: [
    {
      account_public_id: "acc_two",
      organization_public_id: "org_two",
      organization_unit_public_id: "unit_two",
    },
  ],
};

describe("app selector page", () => {
  it("shows the selection error, requires a candidate, then patches that candidate", () => {
    const { rerender } = render(
      <AppSelectorShow
        {...appSelectorProps}
        candidates={[]}
      />,
    );

    expect(screen.getByText("No identities are available.")).toBeTruthy();
    expect(screen.getByText("Selection expired.")).toBeTruthy();
    rerender(
      <AppSelectorShow
        {...appSelectorProps}
        error={null}
      />,
    );
    const form = screen.getByRole("button", { name: "Continue" }).closest("form")!;

    fireEvent.submit(form);
    expect(patchRequest).not.toHaveBeenCalled();

    fireEvent.click(screen.getByRole("radio", { name: /acc_one/u }));
    fireEvent.submit(form);
    const [url, data, visit] = present(patchRequest.mock.calls.at(-1), "app selector PATCH call");
    expect(url).toBe("/identity/selection");
    expect(data).toEqual(appSelectorProps.candidates[0]);
    expect(visit?.onStart).toBeTypeOf("function");
    expect(visit?.onFinish).toBeTypeOf("function");
    const submit = screen.getByRole<HTMLButtonElement>("button", { name: "Continue" });
    act(() => startVisit(visit));
    expect(submit.disabled).toBe(true);
    act(() => finishVisit(visit));
    expect(submit.disabled).toBe(false);
  });
});

describe("organization selector page", () => {
  it("renders an empty state or patches the chosen organization candidate", () => {
    const { rerender } = render(
      <OrgSelectorShow
        {...orgSelectorProps}
        candidates={[]}
      />,
    );

    expect(screen.getByText("No workspaces are available.")).toBeTruthy();
    rerender(
      <OrgSelectorShow
        {...orgSelectorProps}
        error="Selection expired."
      />,
    );
    expect(screen.getByText("Selection expired.")).toBeTruthy();
    const form = screen.getByRole("button", { name: "Continue" }).closest("form")!;
    fireEvent.submit(form);
    expect(patchRequest).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("radio", { name: /org_two/u }));
    fireEvent.submit(form);

    const [url, data, visit] = present(
      patchRequest.mock.calls.at(-1),
      "organization selector PATCH call",
    );
    expect(url).toBe("/organization/selection");
    expect(data).toEqual(orgSelectorProps.candidates[0]);
    expect(visit?.onStart).toBeTypeOf("function");
    expect(visit?.onFinish).toBeTypeOf("function");
    const submit = screen.getByRole<HTMLButtonElement>("button", { name: "Continue" });
    act(() => startVisit(visit));
    expect(submit.disabled).toBe(true);
    act(() => finishVisit(visit));
    expect(submit.disabled).toBe(false);
  });
});
