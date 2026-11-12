import { expect, test } from 'bun:test';
import { PushRegistration } from './push-registration.ts';

test('a failed token or server registration stays retryable and a later attempt connects', async () => {
  const registration = new PushRegistration();
  let calls = 0;
  const native = { available: true, later: async () => { if (++calls === 1) throw new Error('offline'); return { registered: true }; } };
  expect(await registration.update('@test1', 'granted', true, false, 'visible', native)).toEqual({ registered: false, retry: true });
  expect(await registration.update('@test1', 'granted', true, false, 'visible', native)).toEqual({ registered: true, retry: false });
});

test('a token timeout returned as false is retryable too', async () => {
  const registration = new PushRegistration();
  expect(await registration.update('@test1', 'granted', true, false, 'visible',
    { available: true, later: async () => ({ registered: false }) })).toEqual({ registered: false, retry: true });
});

test('unknown permission and backgrounding preserve the server pusher', async () => {
  const registration = new PushRegistration();
  const ops: string[] = [];
  const native = { available: true, later: async ({ op }: { op: string }) => { ops.push(op); return { registered: true }; } };
  await registration.update('@test1', 'unknown', true, false, 'visible', native);
  await registration.update('@test1', 'granted', true, false, 'hidden', native);
  expect(ops).toEqual([]);
  await registration.update('@test1', 'granted', true, false, 'visible', native);
  expect(ops).toEqual(['registerPush']);
});

test('disable waits for in-flight registration, and failed deletion retries', async () => {
  const registration = new PushRegistration();
  let finish!: (value: unknown) => void;
  const ops: string[] = [];
  const native = { available: true, later: async ({ op }: { op: string }) => {
    ops.push(op);
    if (op === 'registerPush') return await new Promise(resolve => { finish = resolve; });
    throw new Error('offline');
  } };
  const enabling = registration.update('@test1', 'granted', true, false, 'visible', native);
  await Promise.resolve();
  const disabling = registration.update('@test1', 'granted', false, false, 'visible', native);
  expect(ops).toEqual(['registerPush']);
  finish({ registered: true });
  await enabling;
  expect(await disabling).toEqual({ registered: false, retry: true });
  expect(ops).toEqual(['registerPush', 'unregisterPush']);
});

test('signed out, desktop and unavailable native contexts never register', async () => {
  const registration = new PushRegistration();
  const native = { available: true, later: async () => { throw new Error('must not call'); } };
  for (const [user, desktop] of [['', false], ['@test1', true]] as const) {
    expect(await registration.update(user, 'granted', true, desktop, 'visible', native)).toEqual({ registered: false, retry: false });
  }
});
