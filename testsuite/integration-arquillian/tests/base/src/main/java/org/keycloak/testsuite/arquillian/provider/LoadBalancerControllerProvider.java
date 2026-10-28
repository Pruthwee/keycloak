package org.keycloak.testsuite.arquillian.provider;

import java.lang.annotation.Annotation;

import org.keycloak.testsuite.arquillian.LoadBalancerController;
import org.keycloak.testsuite.arquillian.annotation.LoadBalancer;


/**
 *
 * @author hmlnarik
 */
public class LoadBalancerControllerProvider implements ResourceProvider {

    @Inject
    private Instance<ContainerRegistry> registry;

    @Override
    public boolean canProvide(Class<?> type) {
        return type.equals(LoadBalancerController.class);
    }

    @Override
    public Object lookup(ArquillianResource resource, Annotation... qualifiers) {
        String balancerName = null;

        // Check for the presence of possible qualifiers
        for (Annotation a : qualifiers) {
            Class<? extends Annotation> annotationType = a.annotationType();

            if (annotationType.equals(LoadBalancer.class)) {
                balancerName = ((LoadBalancer) a).value();
            }
        }

        ContainerRegistry reg = registry.get();
        Container container = null;
        if (balancerName == null || "".equals(balancerName.trim())) {
            if (reg.getContainers().size() == 1) {
                container = reg.getContainers().get(0);
            } else {
                throw new IllegalArgumentException("Invalid load balancer configuration request - need to specify load balancer name in @LoadBalancerController");
            }
        } else {
            container = reg.getContainer(balancerName);
        }

        if (container == null) {
            throw new IllegalArgumentException("Invalid load balancer configuration - load balancer not found: '" + balancerName + "'");
        }
        if (! (container.getDeployableContainer() instanceof LoadBalancerController)) {
            throw new IllegalArgumentException("Invalid load balancer configuration - container " + container.getName() + " is not a load balancer");
        }

        return container.getDeployableContainer();
    }
}
