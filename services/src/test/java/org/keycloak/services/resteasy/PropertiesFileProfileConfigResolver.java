package org.keycloak.services.resteasy;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.Properties;

import org.keycloak.common.profile.ProfileException;
import org.keycloak.common.profile.PropertiesProfileConfigResolver;


public class PropertiesFileProfileConfigResolver extends PropertiesProfileConfigResolver {

    public PropertiesFileProfileConfigResolver() {
        super(loadProperties());
    }

    private static Properties loadProperties() {
        // Cloud: retrieve configuration from AWS Systems Manager Parameter Store
        Properties properties = new Properties();
        try {
            String jbossServerConfigDir = System.getProperty("jboss.server.config.dir");
            if (jbossServerConfigDir != null) {
                // Cloud: consider using Amazon S3 for durable storage instead of java.io.File
                File file = new File(jbossServerConfigDir, "profile.properties");
                if (file.isFile()) {
                    try (FileInputStream is = new FileInputStream(file)) {
                        properties.load(is);
                    }
                }
            }
        } catch (IOException e) {
            throw new ProfileException("Failed to load profile properties file", e);
        }
        return properties;
    }

}
