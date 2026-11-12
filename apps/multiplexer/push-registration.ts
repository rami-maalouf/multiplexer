// serialize preference changes: an older registration must finish before a newer disable.
export type PushState = { registered: boolean; retry: boolean };
export type PushNative = { available: boolean; later(request: { op: string }): Promise<unknown> };

export class PushRegistration {
  private tail: Promise<unknown> = Promise.resolve();
  private revision = 0;

  update(user: string, permission: string, enabled: boolean, desktop: boolean, visibility: string,
         native?: PushNative | null): Promise<PushState> {
    const revision = ++this.revision;
    const run = async (): Promise<PushState> => {
      if (revision !== this.revision || !user || desktop || !native?.available) return { registered: false, retry: false };
      // an unknown permission is not a revocation. keep a working server registration.
      if (enabled && permission === 'unknown') return { registered: false, retry: true };
      const register = enabled && permission === 'granted';
      if (register && visibility !== 'visible') return { registered: false, retry: true };
      try {
        const result = await native.later({ op: register ? 'registerPush' : 'unregisterPush' }) as { registered?: boolean };
        return { registered: register && result.registered === true, retry: register && result.registered !== true };
      } catch {
        // both token acquisition and server requests can fail offline. the view retries.
        return { registered: false, retry: true };
      }
    };
    const result = this.tail.then(run, run);
    this.tail = result;
    return result;
  }
}
