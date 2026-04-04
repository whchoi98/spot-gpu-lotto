import { useAuth } from "@/hooks/useAuth";
import { Badge } from "@/components/ui/badge";

export function Header() {
  const user = useAuth();

  return (
    <header className="flex h-14 items-center justify-between border-b px-6">
      <div />
      <div className="flex items-center gap-3">
        <span className="text-sm text-muted-foreground">{user.user_id}</span>
        <Badge variant={user.role === "admin" ? "default" : "secondary"}>
          {user.role}
        </Badge>
      </div>
    </header>
  );
}
