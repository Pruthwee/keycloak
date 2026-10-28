package org.keycloak.testframework.util;

import java.io.File;

public class TmpDir {

    // Maven overrides java.io.tmpdir, resolving to OS tmp directory
    public static File resolveTmpDir() {
        // Cloud: consider using Amazon S3 for durable storage instead of java.io.File
        File tmpDir = new File(System.getenv().getOrDefault("APP_DATA_DIR", "/tmp")));
        if (tmpDir.isDirectory()) {
            return tmpDir;
        }
        tmpDir = new File(System.getenv("TEMP"));
        if (tmpDir.isDirectory()) {
            return tmpDir;
        }
        return new File(System.getProperty("java.io.tmpdir"));
    }

}
