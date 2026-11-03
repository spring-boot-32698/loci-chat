import { IEnv } from './env.model';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const w = (window as any).__env || {};

export const environment: IEnv = {
  production: w.production ?? false,

  socketEndpoint: w.socketEndpoint || 'ws://localhost:8080/api/v1/ws',
  apiUrl:         w.apiUrl         || '//localhost:8080/api/v1',

  keycloak: {
    issuer:   w.keycloak?.issuer   || 'http://localhost:9090',
    realm:    w.keycloak?.realm    || 'loci-realm',
    clientId: w.keycloak?.clientId || 'angular',
  },
};
