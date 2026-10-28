/*
 * Copyright 2018 Red Hat, Inc. and/or its affiliates
 * and other contributors as indicated by the @author tags.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.keycloak.testsuite.arquillian.containers;

import org.keycloak.testsuite.arquillian.ModelTestExecutor;


/**
 * KeycloakContainerTestExtension
 * 
 * This Extension Overrides the original ContainerTestExtension. 
 * 
 * Needed to change the behavior of ContainerEventController 
 * to stopManualContainers @AfterSuite instead of @AfterClass
 *
 * @see base/src/main/resources/META-INF/services/org.jboss.arquillian.core.spi.LoadableExtension
 * @see https://issues.jboss.org/browse/ARQ-2186
 * 
 * @author vramik
 * @version $Revision: $
 */
public class KeycloakContainerTestExtension implements LoadableExtension {
    @Override
    public void register(ExtensionBuilder builder) {
        registerOriginal(builder);
        
//      Overriden ContainerEventController
        builder.observer(KeycloakContainerEventsController.class);
        
        // overriden ContainerDeployController
        builder.observer(KeycloakContainerDeployController.class);
    }
    
    private void registerOriginal(ExtensionBuilder builder) {
        // Start -> Copied from TestExtension
        builder.context(SuiteContextImpl.class)
            .context(ClassContextImpl.class)
            .context(TestContextImpl.class);

        builder.observer(TestContextHandler.class)
            .observer(ClientTestInstanceEnricher.class);

        // End -> Copied from TestExtension

        builder.service(AuxiliaryArchiveAppender.class, ArquillianDeploymentAppender.class)
            .service(TestEnricher.class, ArquillianResourceTestEnricher.class)
            .service(Protocol.class, LocalProtocol.class)
            .service(CommandService.class, LocalCommandService.class)
            .service(ResourceProvider.class, URLResourceProvider.class)
            .service(ResourceProvider.class, URIResourceProvider.class)
            .service(ResourceProvider.class, DeployerProvider.class)
            .service(ResourceProvider.class, InitialContextProvider.class)
            .service(ResourceProvider.class, ContainerControllerProvider.class);

//        ContainerEventController is overriden
//        builder.observer(ContainerEventController.class)
          builder.observer(ContainerRestarter.class)
            .observer(DeploymentGenerator.class)
            .observer(ArchiveDeploymentToolingExporter.class)
            .observer(ProtocolRegistryCreator.class)
            .observer(ClientContainerControllerCreator.class)
            .observer(ClientDeployerCreator.class)
            .observer(ClientBeforeAfterLifecycleEventExecuter.class)
            .observer(ClientTestExecuter.class)
//            .observer(LocalTestExecuter.class)
            .observer(ModelTestExecutor.class)
            .observer(RemoteTestExecuter.class)
            .observer(DeploymentCommandObserver.class)
            .observer(ContainerCommandObserver.class)
            .observer(RemoteResourceCommandObserver.class)
            .observer(KeycloakContainerFeaturesController.class);
    }
}
