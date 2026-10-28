const DEFAULT_SERVER_URL = process.env.API_URL || "$1";
const normalizeServerUrl = (url: string) => url.replace(/\/$/, "");

export const SERVER_URL = normalizeServerUrl(
  process.env.KEYCLOAK_SERVER_URL ?? DEFAULT_SERVER_URL,
);
export const ROOT_PATH = "/admin/:realm/console";
export const DEFAULT_REALM = "master";
export const ADMIN_USER = process.env.KEYCLOAK_ADMIN_USER ?? "admin";
export const ADMIN_PASSWORD = process.env.KEYCLOAK_ADMIN_PASSWORD ?? "admin";
