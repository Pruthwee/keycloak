package org.keycloak.saml.processing.core.parsers.saml.metadata;

/**
 * @author mhajas
 */
public class SAMLManageNameIDServiceParser extends SAMLEndpointTypeParser {

    private static final SAMLManageNameIDServiceParser INSTANCE = new SAMLManageNameIDServiceParser();

    public SAMLManageNameIDServiceParser() {
        super(SAMLMetadataQNames.MANAGE_NAMEID_SERVICE);
    }

    // Cloud: consider using AWS DynamoDB for shared singleton state
    public static SAMLManageNameIDServiceParser getInstance() {
        return INSTANCE;
    }
}
