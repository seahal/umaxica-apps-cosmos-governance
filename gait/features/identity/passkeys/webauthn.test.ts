import { afterEach, describe, expect, it, vi } from "vitest";

import {
  createCredential,
  getAssertion,
  passkeysSupported,
} from "@/features/identity/passkeys/webauthn";

import { present } from "../../../support/present";
import { stubCredentialsApi } from "../../../support/webauthn";

const creationOptions = {
  challenge: "Y2hhbGxlbmdl",
  rp: { name: "Umaxica", id: "example.test" },
  user: { id: "dXNlcg", name: "visitor@example.test", displayName: "Visitor" },
  pubKeyCredParams: [{ type: "public-key", alg: -7 }],
};

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("passkeysSupported", () => {
  it("reports whether the browser exposes the WebAuthn credential constructor", () => {
    vi.stubGlobal("PublicKeyCredential", undefined);
    expect(passkeysSupported()).toBe(false);

    vi.stubGlobal("PublicKeyCredential", function PublicKeyCredential() {});
    expect(passkeysSupported()).toBe(true);
  });
});

describe("getAssertion", () => {
  it("serializes assertion buffers and preserves an absent user handle as null", async () => {
    const credential = Object.assign(
      { id: "credential-id", type: "public-key" },
      {
        rawId: new Uint8Array([1, 2, 3]).buffer,
        authenticatorAttachment: null,
        response: {
          clientDataJSON: new Uint8Array([4]).buffer,
          authenticatorData: new Uint8Array([5]).buffer,
          signature: new Uint8Array([6]).buffer,
          userHandle: null,
        },
        getClientExtensionResults: () => ({}),
      },
    );
    const { get } = stubCredentialsApi();
    get.mockResolvedValue(credential);

    await expect(getAssertion({ challenge: "Y2hhbGxlbmdl" })).resolves.toEqual({
      id: "credential-id",
      rawId: "AQID",
      type: "public-key",
      authenticatorAttachment: null,
      response: {
        clientDataJSON: "BA",
        authenticatorData: "BQ",
        signature: "Bg",
        userHandle: null,
      },
      clientExtensionResults: {},
    });
    const requestOptions = present(get.mock.calls.at(-1)?.[0], "the authenticator request options");
    const publicKey = present(requestOptions.publicKey, "the authenticator public key options");
    expect(publicKey.challenge).toBeInstanceOf(ArrayBuffer);
  });

  it("rejects an empty authenticator response", async () => {
    const { get } = stubCredentialsApi();
    get.mockResolvedValue(null);

    await expect(getAssertion({ challenge: "Y2hhbGxlbmdl" })).rejects.toThrow(
      "No credential was returned by the authenticator",
    );
  });

  it.each([
    ["without rawId", { response: {} }],
    ["without response", { rawId: new ArrayBuffer(0) }],
    ["with a null response", { rawId: new ArrayBuffer(0), response: null }],
    ["with a non-object response", { rawId: new ArrayBuffer(0), response: "invalid" }],
    [
      "without an assertion signature",
      {
        rawId: new ArrayBuffer(0),
        response: { clientDataJSON: new ArrayBuffer(0), authenticatorData: new ArrayBuffer(0) },
      },
    ],
  ])("rejects a credential %s", async (_label, malformed) => {
    const credential: Credential = Object.assign(
      { id: "credential-id", type: "public-key" },
      malformed,
    );
    const { get } = stubCredentialsApi();
    get.mockResolvedValue(credential);

    await expect(getAssertion({ challenge: "Y2hhbGxlbmdl" })).rejects.toThrow(
      "The authenticator returned a credential that is not a WebAuthn assertion",
    );
  });
});

describe("createCredential", () => {
  it("serializes the attestation and reports no transports when the browser omits them", async () => {
    const credential = Object.assign(
      { id: "credential-id", type: "public-key" },
      {
        rawId: new Uint8Array([1, 2, 3]).buffer,
        authenticatorAttachment: "platform",
        response: {
          clientDataJSON: new Uint8Array([4]).buffer,
          attestationObject: new Uint8Array([7, 8]).buffer,
        },
        getClientExtensionResults: () => ({ appid: true }),
      },
    );
    const { create } = stubCredentialsApi();
    create.mockResolvedValue(credential);

    await expect(createCredential(creationOptions)).resolves.toEqual({
      id: "credential-id",
      rawId: "AQID",
      type: "public-key",
      authenticatorAttachment: "platform",
      response: {
        clientDataJSON: "BA",
        attestationObject: "Bwg",
        transports: [],
      },
      clientExtensionResults: { appid: true },
    });
    const creationRequest = present(
      create.mock.calls.at(-1)?.[0],
      "the authenticator creation options",
    );
    const publicKey = present(creationRequest.publicKey, "the authenticator public key options");
    expect(publicKey.challenge).toBeInstanceOf(ArrayBuffer);
  });

  it("includes browser-reported transports", async () => {
    const credential = Object.assign(
      { id: "credential-id", type: "public-key" },
      {
        rawId: new ArrayBuffer(0),
        authenticatorAttachment: null,
        response: {
          clientDataJSON: new ArrayBuffer(0),
          attestationObject: new ArrayBuffer(0),
          getTransports: () => ["internal", "hybrid"],
        },
        getClientExtensionResults: () => ({}),
      },
    );
    const { create } = stubCredentialsApi();
    create.mockResolvedValue(credential);

    await expect(createCredential(creationOptions)).resolves.toMatchObject({
      authenticatorAttachment: null,
      response: { transports: ["internal", "hybrid"] },
    });
  });

  it("rejects an empty creation response", async () => {
    const { create } = stubCredentialsApi();
    create.mockResolvedValue(null);

    await expect(createCredential(creationOptions)).rejects.toThrow(
      "No credential was returned by the authenticator",
    );
  });

  it("rejects an attestation without the required response fields", async () => {
    const credential = Object.assign(
      { id: "credential-id", type: "public-key" },
      {
        rawId: new ArrayBuffer(0),
        authenticatorAttachment: null,
        response: { clientDataJSON: new ArrayBuffer(0) },
        getClientExtensionResults: () => ({}),
      },
    );
    const { create } = stubCredentialsApi();
    create.mockResolvedValue(credential);

    await expect(createCredential(creationOptions)).rejects.toThrow(
      "The authenticator returned a credential that is not a WebAuthn attestation",
    );
  });
});
