export type CumaruCache = {
  [key: string]: string;
};

export type ExtendedError = Error & { code: string };

export * from "./cumaru";
