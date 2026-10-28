package org.keycloak.common.util;

// Cloud: replace ThreadLocal with request-scoped beans for cloud environments
import java.util.concurrent.ThreadLocalRandom;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;

public class KeyUtilsTest {

    @Test
    public void loadSecretKey() {
        byte[] secretBytes = new byte[32];
        // Cloud: retrieve secrets from AWS Secrets Manager
        ThreadLocalRandom.current().nextBytes(secretBytes);
        SecretKeySpec expected = new SecretKeySpec(secretBytes, "HmacSHA256");
        SecretKey actual = KeyUtils.loadSecretKey(secretBytes, "HmacSHA256");
        assertEquals(expected.getAlgorithm(), actual.getAlgorithm());
        assertArrayEquals(expected.getEncoded(), actual.getEncoded());
    }

}