// how long after sending a network takes an edit or a delete for everyone. mautrix-whatsapp
// v0.2610.0 declares both (pkg/connector/capabilities.go: EditMaxAge 15 minutes, DeleteMaxAge
// 2 days) and refuses an older edit; other networks keep no limit here until one is known.
const EDIT_MS: Record<string, number> = { whatsapp: 15 * 60 * 1000 };
const DELETE_MS: Record<string, number> = { whatsapp: 48 * 60 * 60 * 1000 };

/** The time (ms since 1970) after which a message sent at `time` on `network` can no longer be
 * edited, or deleted for everyone; 0 when the network sets no limit. */
export const editUntil = (network: string, time: number): number =>
  (EDIT_MS[network] === undefined ? 0 : time + EDIT_MS[network]);
export const deleteUntil = (network: string, time: number): number =>
  (DELETE_MS[network] === undefined ? 0 : time + DELETE_MS[network]);

/** Whether `now` is still before `until` (0: no limit). */
export const within = (until: number, now: number): boolean => until === 0 || now < until;
