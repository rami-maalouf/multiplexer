import type { Result } from './app.contract.d.ts';

export type DesktopNotificationRoom = Pick<Result<'loadRoomsByRecency'>['rooms'][number],
  'id' | 'name' | 'isDirect' | 'lastMessage' | 'lastSender' | 'lastIsOwn' | 'lastTime' |
  'unread' | 'listed' | 'muted' | 'mentions' | 'merge' | 'open' | 'mergeRooms'>;

export type DesktopNotificationSnapshot = {
  userId: string;
  rooms: readonly DesktopNotificationRoom[];
  openRoom: string;
  foreground: boolean;
  visible: boolean;
  notificationsEnabled: boolean;
  permissionGranted: boolean;
  now: number;
};

export type DesktopNotification = { title: string; body: string; tag: string; data: string };

export class DesktopNotifications {
  private userId = '';
  private startedAt = 0;
  private observed = new Map<string, { time: number; mentions: number }>();

  // call for every unfiltered account snapshot, including signout (userId = '').
  // now and lastTime are milliseconds since the epoch; no system clock is read here.
  update(snapshot: DesktopNotificationSnapshot): DesktopNotification[] {
    const { userId, rooms, openRoom, foreground, visible, notificationsEnabled, permissionGranted, now } = snapshot;
    const startup = userId !== this.userId;
    if (startup) {
      this.userId = userId;
      this.startedAt = now;
      this.observed.clear();
    }
    if (!userId) return [];

    const mergedByChild = new Map(rooms.flatMap((room) => room.mergeRooms.map((child) => [child.id, room] as const)));
    const notices = new Map<string, { time: number; notice: DesktopNotification }>();
    for (const room of rooms) {
      const previous = this.observed.get(room.id);
      // keep the high water mark even when rooms disappear or an older snapshot arrives.
      // preview edits and receipt updates are not message identities. without event ids,
      // two messages sharing a timestamp cannot both notify.
      this.observed.set(room.id, {
        time: Math.max(previous?.time ?? 0, room.lastTime), mentions: room.mentions,
      });
      if (startup || room.lastTime <= Math.max(this.startedAt, previous?.time ?? 0)) continue;
      if (room.mergeRooms.length > 0) continue;
      if (room.lastIsOwn || !notificationsEnabled || !permissionGranted) continue;
      if (room.unread <= 0 && room.mentions <= 0) continue;
      if (room.muted && room.mentions <= (previous?.mentions ?? 0)) continue;
      const display = mergedByChild.get(room.id) ?? room;
      const selected = openRoom === display.id || openRoom === room.id || display.mergeRooms.some((r) => r.id === openRoom);
      if (foreground && visible && selected) continue;

      const message = room.lastMessage || 'New message';
      const tag = `chat:${userId}:${display.id}`;
      const notice = {
        title: display.name,
        body: !room.isDirect && room.lastSender ? `${room.lastSender}: ${message}` : message,
        tag,
        data: room.open || room.id,
      };
      if (room.lastTime >= (notices.get(tag)?.time ?? 0)) notices.set(tag, { time: room.lastTime, notice });
    }
    return [...notices.values()].map((entry) => entry.notice);
  }
}

export class DesktopNotificationDelivery {
  private key = '';
  private generation = 0;

  configure(userId: string, enabled: boolean, permissionGranted: boolean): number {
    const key = JSON.stringify([userId, enabled, permissionGranted]);
    if (key !== this.key) { this.key = key; this.generation++; }
    return this.generation;
  }

  async send(notices: DesktopNotification[], generation: number, show: (notice: DesktopNotification) => Promise<unknown>): Promise<number> {
    let delivered = 0;
    for (const notice of notices) {
      if (generation !== this.generation) break;
      try { await show(notice); delivered++; }
      catch (error) { console.log(`desktop notification: ${error}`); }
    }
    return delivered;
  }
}
