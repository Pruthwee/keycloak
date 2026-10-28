package org.keycloak.saml.processing.core.parsers.saml.metadata;

/**
 * @author mhajas
 */
public class SAMLNameIDMappingServiceParser extends SAMLEndpointTypeParser {

    private static final SAMLNameIDMappingServiceParser INSTANCE = new SAMLNameIDMappingServiceParser();

    public SAMLNameIDMappingServiceParser() {
        super(SAMLMetadataQNames.NAMEID_MAPPING_SERVICE);
    }

    // Cloud: consider using Amazon ElastiCache for Redis for shared mutable state
    public static SAMLNameIDMappingServiceParser getInstance() {
        return INSTANCE;
    }
}
