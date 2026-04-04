import { createContext, useContext } from "react";
import type { UserInfo } from "@/lib/types";

export const AuthContext = createContext<UserInfo>({
  user_id: "dev-user",
  role: "admin",
});

export function useAuth(): UserInfo {
  return useContext(AuthContext);
}
