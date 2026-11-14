# openURL has no "only in an app that claims it" form

- date: 2026-11-14
- severity: P3
- cost: about 12 minutes

A chat app opens tapped links in the in-app browser. A link that an installed app claims (a
universal link: a map, a photo album, a social post) should open in that app instead, and only
fall back to the in-app browser when no app claims it.

iOS supports this with `UIApplication.open(url, options: [.universalLinksOnly: true])`, whose
answer says whether an app took the link. Neither `openURL(url, id)` nor `@exact/in-app-browser`
offers it: `openURL` always leaves for Safari when no app claims the link, and `openBrowser`
never asks. The app needed its own native op, and a mutation's `then` action to open the
in-app browser when the op answered "not opened".

The app module's context also has no log call (packages have `context.log`), so the op could not
journal what it asked under the agent. About 2 minutes: a build error, then the line was dropped.

What would help:
- `openBrowser(url=..., preferApp=true)`, or an `openURL` form that opens only in a claiming app
  and answers `failed` otherwise.
- A log call on the app module's context, as packages have.

No app name, account or message content is included.
