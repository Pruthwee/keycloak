package org.keycloak.testsuite.arquillian.undertow;

import org.keycloak.testsuite.arquillian.undertow.lb.SimpleUndertowLoadBalancerContainer;


/**
 *
 * @author tkyjovsk
 */
public class KeycloakOnUndertowArquillianExtension implements LoadableExtension {

    @Override
    public void register(ExtensionBuilder builder) {
        builder.service(DeployableContainer.class, KeycloakOnUndertow.class);
        builder.service(DeployableContainer.class, SimpleUndertowLoadBalancerContainer.class);
    }

}
