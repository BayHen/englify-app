export const designTokens = {
  color: {
    primary: "#7456F1",
    reward: "#FFC857",
    success: "#37C99B",
    error: "#FF7B82",
    background: "#F7F5FF",
  },
} as const;

export type ApiHealth = { status: "ok" };

export function apiPath(path: string): string {
  return `/api/v1/${path.replace(/^\/+/, "")}`;
}
