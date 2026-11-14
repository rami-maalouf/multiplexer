import type { Result, Sources } from './app.contract.d.ts';

// a link that an installed app claims (a universal link: Instagram, Google Maps, Google Photos,
// ...) opens in that app (modules/apple/AppLinks.swift). The answer says whether one did, so the
// chat shows any other in the in-app browser (details-members.contract's openLink).
export const appLinkSources: Pick<Sources, 'openInApp'> = {
  openInApp: async ([url], _store, _storage, native): Promise<Result<'openInApp'>> => {
    if (!native?.available) return { url, opened: false };
    return (await native.later({ op: 'openInApp', url }).catch(() => ({ url, opened: false }))) as Result<'openInApp'>;
  },
};
