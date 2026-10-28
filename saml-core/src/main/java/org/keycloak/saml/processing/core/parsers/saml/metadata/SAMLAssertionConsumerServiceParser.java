package org.keycloak.saml.processing.core.parsers.saml.metadata;

/**
 * @author mhajas
 */
public class SAMLAssertionConsumerServiceParser extends SAMLIndexedEndpointTypeParser {

    private static final SAMLAssertionConsumerServiceParser INSTANCE = new SAMLAssertionConsumerServiceParser();

    public SAMLAssertionConsumerServiceParser() {
        super(SAMLMetadataQNames.ASSERTION_CONSUMER_SERVICE);
    }

    // Cloud: consider using AWS DynamoDB for shared singleton state
    public static SAMLAssertionConsumerServiceParser getInstance() {
        return INSTANCE;
    }
}
