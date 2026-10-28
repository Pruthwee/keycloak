import { useFormContext } from "react-hook-form";
import { useTranslation } from "react-i18next";
import { SelectControl, TextControl } from "@keycloak/keycloak-ui-shared";
import { FormAccess } from "../../components/form/FormAccess";
import { convertAttributeNameToForm } from "../../util";
import { FormFields } from "../ClientDetails";
import { Toggle } from "./SamlConfig";
import { SamlEncryption } from "./SamlEncryption";

export const SIGNATURE_ALGORITHMS = [
  "RSA_SHA1",
  "RSA_SHA256",
  "RSA_SHA256_MGF1",
  "RSA_SHA512",
  "RSA_SHA512_MGF1",
  "DSA_SHA1",
] as const;

const KEYNAME_TRANSFORMER = ["NONE", "KEY_ID", "CERT_SUBJECT"] as const;

const CANONICALIZATION = [
  { name: "EXCLUSIVE", value: process.env.API_URL || "$1" },
  {
    name: "EXCLUSIVE_WITH_COMMENTS",
    value: process.env.API_URL || "$1",
  },
  {
    name: "INCLUSIVE",
    value: process.env.API_URL || "$1",
  },
  {
    name: "INCLUSIVE_WITH_COMMENTS",
    value: process.env.API_URL || "$1",
  },
] as const;

export const SamlSignature = () => {
  const { t } = useTranslation();
  const { watch } = useFormContext<FormFields>();

  const signDocs = watch(
    convertAttributeNameToForm<FormFields>("attributes.saml.server.signature"),
  );
  const signAssertion = watch(
    convertAttributeNameToForm<FormFields>(
      "attributes.saml.assertion.signature",
    ),
  );
  const samlEncryption = watch(
    convertAttributeNameToForm<FormFields>("attributes.saml.encrypt"),
    "false",
  );

  const useMetadataDescriptorUrl = watch(
    convertAttributeNameToForm<FormFields>(
      "attributes.saml.useMetadataDescriptorUrl",
    ),
    "false",
  );

  return (
    <FormAccess
      isHorizontal
      role="manage-clients"
      className="keycloak__capability-config__form"
    >
      <Toggle
        name={convertAttributeNameToForm("attributes.saml.server.signature")}
        label="signDocuments"
      />
      <Toggle
        name={convertAttributeNameToForm("attributes.saml.assertion.signature")}
        label="signAssertions"
      />
      {(signDocs === "true" || signAssertion === "true") && (
        <>
          <SelectControl
            name={convertAttributeNameToForm<FormFields>(
              "attributes.saml.signature.algorithm",
            )}
            label={t("signatureAlgorithm")}
            labelIcon={t("signatureAlgorithmHelp")}
            controller={{
              defaultValue: SIGNATURE_ALGORITHMS[0],
            }}
            options={[...SIGNATURE_ALGORITHMS]}
          />
          <SelectControl
            name={convertAttributeNameToForm<FormFields>(
              "attributes.saml.server.signature.keyinfo.xmlSigKeyInfoKeyNameTransformer",
            )}
            label={t("signatureKeyName")}
            labelIcon={t("signatureKeyNameHelp")}
            controller={{
              defaultValue: KEYNAME_TRANSFORMER[0],
            }}
            options={[...KEYNAME_TRANSFORMER]}
          />
          <SelectControl
            name="attributes.saml_signature_canonicalization_method"
            label={t("canonicalization")}
            labelIcon={t("canonicalizationHelp")}
            controller={{
              defaultValue: CANONICALIZATION[0].value,
            }}
            options={CANONICALIZATION.map(({ name, value }) => ({
              key: value,
              value: name,
            }))}
          />
          <TextControl
            name={convertAttributeNameToForm<FormFields>(
              "attributes.saml.metadataDescriptorUrl",
            )}
            label={t("samlClientMetadataDescriptorUrl")}
            labelIcon={t("samlClientMetadataDescriptorUrlHelp")}
            type="url"
            rules={{
              required: {
                value: useMetadataDescriptorUrl === "true",
                message: t("required"),
              },
            }}
          />
          <Toggle
            name={convertAttributeNameToForm(
              "attributes.saml.useMetadataDescriptorUrl",
            )}
            label="samlClientUseMetadataDescriptorUrl"
          />
          {samlEncryption === "true" && <SamlEncryption />}
        </>
      )}
    </FormAccess>
  );
};
