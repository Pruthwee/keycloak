package org.keycloak.common.util;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

public class EnvUtilTest {

    @Test
    public void replaceValueContainingDollarSign() {
        String key = "keycloak.test.envutil.dollar";
        try {
            // A resolved value containing '$' must be inserted literally.
            System.setProperty(key, "abc$def");
            assertEquals("abc$def", EnvUtil.replace("${" + key + "}"));

            System.setProperty(key, "a$1b");
            assertEquals("a$1b", EnvUtil.replace("${" + key + "}"));
        } finally {
            System.clearProperty(key);
        }
    }

    @Test
    public void replaceValueContainingBackslash() {
        // Backslashes (e.g. Windows keystore paths) must still be preserved literally.
        String key = "keycloak.test.envutil.backslash";
        String testPath = System.getenv().getOrDefault("TEST_KEYSTORE_PATH", "C:\\keys\\truststore.jks");
        try {
            System.setProperty(key, testPath);
            assertEquals(testPath, EnvUtil.replace("${" + key + "}"));
        } finally {
            System.clearProperty(key);
        }
    }

    @Test
    public void replaceUnspecifiedPropertyYieldsPlaceholder() {
        assertEquals("NOT-SPECIFIED", EnvUtil.replace("${keycloak.test.envutil.missing}"));
    }
}
