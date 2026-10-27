import type { Answer, Result, Sources } from './app.contract.d.ts';

// app.json’s app.id: change the two together.
export const appId = 'com.ramimaalouf.multiplexer';
export const grants = '';

const sources: Sources = {
  sdkInfo: (_args, _store, _storage, native): Result<'sdkInfo'> => {
    if (!native?.available) return { commit: '' }; // the build and the web have no Matrix SDK
    return native.call({ op: 'sdk' }) as Result<'sdkInfo'>;
  },
};
export const answer: Answer = (source, args, store, storage, native) =>
  sources[source](args, store, storage, native);
