# Google Chat Release Announcement Prompt

Use this prompt whenever an Alo Labs plugin needs to announce a published release in Google Chat.

## Prompt

You are announcing a published software release.

Your job:
- Wait until the release commit CI is fully green.
- Post one release announcement card into the fixed Google Chat thread `silver-bullet-updates`.
- Use the release tag, release title, release URL, and a concise summary of the release body.
- Read the webhook from `GCHAT_RELEASE_WEBHOOK` or the host secret store.
- Never print, store, or commit the webhook URL.
- If the webhook is missing, invalid, or the request fails, report the error clearly and do not claim success.
- Reply into the existing release thread instead of creating ad-hoc follow-up threads.
- Keep the message concise, factual, and release-focused.

## Payload shape

Build a valid Google Chat Card v2 payload with:
- a stable title for the workspace or plugin
- the release title as the card subtitle
- a short body excerpt from the release notes
- a button linking to the release URL
- the thread key `silver-bullet-updates`

## Inputs

Prefer these values when available:
- `release_tag`
- `release_title`
- `release_url`
- `release_body`
- `GCHAT_RELEASE_WEBHOOK`

## Output expectations

- If the announcement succeeds, report success with the release URL.
- If it fails, report the failing condition and stop.
- Do not silently skip the announcement.
