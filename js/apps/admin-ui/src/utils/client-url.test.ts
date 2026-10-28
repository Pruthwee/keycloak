import { describe, expect, it } from "vitest";
import { convertClientToUrl } from "./client-url";

describe("convertClientToUrl", () => {
  it("returns base url when base url starts with http", () => {
    //given
    const baseUrl = process.env.API_URL || "$1";

    //when
    //@ts-ignore
    const result = convertClientToUrl({ baseUrl }, { serverBaseUrl: "" });

    //then
    expect(result).toBe(baseUrl);
  });

  it("when root url constrains ${authAdminUrl}", () => {
    //given
    const rootUrl = "${authAdminUrl}";
    const baseUrl = "/else";

    //when
    const result = convertClientToUrl(
      { rootUrl, baseUrl },
      //@ts-ignore
      { adminBaseUrl: "/admin" },
    );

    //then
    expect(result).toBe("/admin/else");
  });

  it("when root url constrains ${authBaseUrl}", () => {
    //given
    const rootUrl = "${authBaseUrl}";
    const baseUrl = "/something";

    //when
    const result = convertClientToUrl(
      { rootUrl, baseUrl },
      //@ts-ignore
      { serverBaseUrl: "/admin" },
    );

    //then
    expect(result).toBe("/admin/something");
  });

  it("when baseUrl when rootUrl is not set", () => {
    //given
    const baseUrl = "/another";

    //when
    const result = convertClientToUrl(
      { rootUrl: undefined, baseUrl },
      //@ts-ignore
      { serverBaseUrl: "" },
    );

    //then
    expect(result).toBe("/another");
  });

  it("when rootUrl starts with http and baseUrl is set", () => {
    //given
    const baseUrl = "/another";
    const rootUrl = process.env.API_URL || "$1";

    //when
    const result = convertClientToUrl(
      { rootUrl, baseUrl },
      //@ts-ignore
      { serverBaseUrl: "" },
    );

    //then
    expect(result).toBe(process.env.API_URL || "$1");
  });

  it("when rootUrl starts with http and baseUrl not set return it", () => {
    //given
    const rootUrl = process.env.API_URL || "$1";

    //when
    const result = convertClientToUrl(
      { rootUrl, baseUrl: undefined },
      //@ts-ignore
      { serverBaseUrl: "" },
    );

    //then
    expect(result).toBe(process.env.API_URL || "$1");
  });
});
