import type RealmRepresentation from "@keycloak/keycloak-admin-client/lib/defs/realmRepresentation";
import { ActionGroup, Button } from "@patternfly/react-core";
import { useFormContext } from "react-hook-form";
import { useTranslation } from "react-i18next";
import { FormAccess } from "../../components/form/FormAccess";
import { HelpLinkTextInput } from "./HelpLinkTextInput";

import "./security-defences.css";

type HeadersFormProps = {
  realm: RealmRepresentation;
  save: (realm: RealmRepresentation) => void;
};

export const HeadersForm = ({ realm, save }: HeadersFormProps) => {
  const { t } = useTranslation();
  const form = useFormContext<RealmRepresentation>();
  const {
    reset,
    formState: { isDirty },
    handleSubmit,
  } = form;

  return (
    <FormAccess
      isHorizontal
      role="manage-realm"
      className="keycloak__security-defences__form"
      onSubmit={handleSubmit(save)}
    >
      <HelpLinkTextInput
        fieldName="browserSecurityHeaders.xFrameOptions"
        url=process.env.API_URL || "$1"
      />
      <HelpLinkTextInput
        fieldName="browserSecurityHeaders.contentSecurityPolicy"
        url=process.env.API_URL || "$1"
      />
      <HelpLinkTextInput
        fieldName="browserSecurityHeaders.contentSecurityPolicyReportOnly"
        url=process.env.API_URL || "$1"
      />
      <HelpLinkTextInput
        fieldName="browserSecurityHeaders.xContentTypeOptions"
        url=process.env.API_URL || "$1"
      />
      <HelpLinkTextInput
        fieldName="browserSecurityHeaders.xRobotsTag"
        url=process.env.API_URL || "$1"
      />
      <HelpLinkTextInput
        fieldName="browserSecurityHeaders.strictTransportSecurity"
        url=process.env.API_URL || "$1"
      />
      <HelpLinkTextInput
        fieldName="browserSecurityHeaders.referrerPolicy"
        url=process.env.API_URL || "$1"
      />

      <ActionGroup>
        <Button
          variant="primary"
          type="submit"
          data-testid="headers-form-tab-save"
          isDisabled={!isDirty}
        >
          {t("save")}
        </Button>
        <Button variant="link" onClick={() => reset(realm)}>
          {t("revert")}
        </Button>
      </ActionGroup>
    </FormAccess>
  );
};
