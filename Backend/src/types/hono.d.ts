import type { AuthenticatedUser } from "../auth/user-auth";

declare module "hono" {
  interface ContextVariableMap {
    authenticatedUser: AuthenticatedUser;
  }
}