# Analytics

Card Almanac measures traffic with **GA4**. The GTM container snippet
(`GTM-5HZ6CZV`) lives in `resources/views/partials/head-gtm.blade.php` — with its
`<noscript>` half in `partials/body-gtm.blade.php` — and is included by every
layout. There is deliberately no `gtag.js` snippet in the codebase.

GA4 property **Card Almanac** (`G-5HFBKYZFKL`, stream `5143941701`) is confirmed
receiving traffic. How the Google tag reaches the page is worth writing down,
because it is not what you would guess:

- The GTM container holds **no GA4 configuration tag**. Opening a GA4 Event tag
  in GTM shows the warning _"No Google tag found in this container."_
- GTM's container overview nonetheless shows a Google tag, `Card Almanac - GA4`
  (`G-5HFBKYZFKL` / `GT-KDTKB27`), sitting between the container and the
  destination.

The likely reading is that the Google tag is linked to the container through
GA4's own install flow rather than existing as a tag object you can edit.
**This has not been verified** — it is inference from the two observations
above. If GA4 event tags ever fire in GTM Preview but nothing lands in GA4,
this is the first thing to check: adding an explicit Google tag to the
container would be the fix.

> The former `partials/analytics.blade.php` hard-coded the Universal Analytics
> property `UA-26467066-4`. Universal Analytics stopped processing hits on
> 1 July 2023 and the properties were deleted in 2024, so that snippet was
> shipping a request that went nowhere. It was removed in #76, along with
> pausing its counterpart tag inside the GTM container — see below.

## Firing an event from the site

`resources/js/analytics.js` is the only thing in the app that touches
`window.dataLayer`. It exposes two entry points.

### Markup-only: `data-analytics-event`

`bindAnalyticsEvents()` (called once from `resources/js/app.js`) attaches a
single **delegated** click listener to the document. Any element carrying
`data-analytics-event` fires that event when clicked — including markup rendered
after page load by Blade partials or Vue components, with no re-binding.

```blade
<a
    href="{{ route('app.index') }}"
    data-analytics-event="view_app_click"
    data-analytics-cta-location="homepage_app_teaser"
>View app</a>
```

Every other `data-analytics-*` attribute becomes a GA4 event parameter, with the
attribute name converted to `snake_case`. The example above pushes:

```js
{ event: "view_app_click", cta_location: "homepage_app_teaser" }
```

Adding a tracked call-to-action is therefore a markup-only change.

### From JavaScript: `pushEvent()`

For events that are not a click — a successful form submission, say — import the
helper directly:

```js
import { pushEvent } from "../analytics";

pushEvent("newsletter_signup", { cta_location: this.ctaLocation });
```

`pushEvent()` seeds `window.dataLayer` itself, so it is safe to call before GTM
has loaded and safe when GTM is blocked by an extension. Callers never need to
guard.

## Events the site currently pushes

| Event                | Where                                                  | Parameters                     |
| -------------------- | ------------------------------------------------------ | ------------------------------ |
| `view_app_click`     | Homepage "View app" CTA (`home/app-teaser-component`)  | `cta_location`                 |
| `blog_article_click` | Homepage featured post CTA (`home/blogpost-component`) | `cta_location`, `article_slug` |
| `newsletter_signup`  | `MailingListForm.vue`, after a successful subscribe    | `cta_location`                 |

`newsletter_signup` is wired but **currently unreachable** — the mailing list
component is commented out in `resources/views/home.blade.php`, and the form
cannot work in production regardless (see the caveat at the end of this file).

## Configuring the key events in GA4

Pushing to the dataLayer is only half the job. A dataLayer event does **not**
reach GA4 on its own: the GTM container (`GTM-5HZ6CZV`) has to listen for it and
forward it. That part lives in your Google account, not in this repo — but the
container objects it needs are checked in as an importable file.

### Import the container objects

`docs/gtm/cardalmanac-ga4-events.json` is a GTM container export containing
everything the homepage CTAs need:

| Object                 | Name                       | Purpose                                             |
| ---------------------- | -------------------------- | --------------------------------------------------- |
| Variable (Constant)    | `GA4 Measurement ID`       | The single place the destination is set             |
| Variable (Data Layer)  | `DLV - cta_location`       | Reads `cta_location` off the dataLayer              |
| Variable (Data Layer)  | `DLV - article_slug`       | Reads `article_slug` off the dataLayer              |
| Trigger (Custom Event) | `CE - view_app_click`      | Fires on `view_app_click`                           |
| Trigger (Custom Event) | `CE - blog_article_click`  | Fires on `blog_article_click`                       |
| Tag (GA4 Event)        | `GA4 - view_app_click`     | Sends the event with `cta_location`                 |
| Tag (GA4 Event)        | `GA4 - blog_article_click` | Sends the event with `cta_location`, `article_slug` |

> **Already applied.** This was imported into workspace `76-homepage-events`
> and published on 2026-09-01 — a clean merge, 7 added / 0 modified / 0 deleted.
> The steps below are the record of how, and what to repeat against another
> container. The remaining GA4-side work is in "After the container is
> published" further down.

To apply it:

1. **Check the destination.** The `GA4 Measurement ID` constant is set to
   `G-5HFBKYZFKL`, the Card Almanac web stream (GA4 → Admin → Data streams).
   Both tags read the destination from that one variable, so pointing this
   container at a different property is a one-line change.
2. **GTM → Admin → Import Container.** Choose the file, import into a **new
   workspace** (e.g. `76-homepage-events`), and pick **Merge → Rename
   conflicting tags, triggers and variables** so nothing already in the
   container is overwritten.
3. Review the diff GTM shows before confirming. It should list 7 additions and
   0 modifications; anything else means the container already had objects by
   these names.
4. Verify in Preview (below), then **Submit** to publish the container version.

Note that `newsletter_signup` is deliberately **not** in the import file — it
cannot fire until the mailing list form is re-enabled (see the caveat below).

### The paused Universal Analytics tag

The same container carried a five-year-old tag, `Google Analytics - pageviews`
(type Universal Analytics, firing on **All Pages**) — the GTM-side twin of the
`partials/analytics.blade.php` snippet #76 deleted from the codebase. It was
sending a pageview hit to a property Google deleted in 2024, on every page load.

It was **paused**, not deleted, in the same container version. Pausing cannot
affect GA4 numbers — UA and GA4 are separate pipelines and GA4 was never fed by
it — and leaves an obvious undo if it turns out to matter. Delete it once
enough time has passed that nobody wants it back.

## Verifying in GTM Preview

Preview works against any site loading the container, including local dev, so
none of this needs a deploy:

1. `make up`, then open https://cardalmanac.dev:8543/.
2. In GTM, click **Preview** and enter that URL.
3. Click the homepage "View app" and "View Article" CTAs. Each should appear in
   the Tag Assistant event stream as `view_app_click` / `blog_article_click`
   with the matching GA4 tag under **Tags Fired**, and the parameters populated
   in the tag's detail view.
4. GA4 → Reports → Realtime confirms the hit actually landed.

If Preview connects but no tags ever fire — and the page's own dataLayer pushes
are happening — check that `www.googletagmanager.com` resolves. Ad-blocking DNS
resolvers (Pi-hole, NextDNS, AdGuard, some VPNs) blackhole that host while
leaving `tagmanager.google.com` reachable, so the GTM admin UI works perfectly
while the container never loads on the site. `dig +short www.googletagmanager.com`
returning nothing is the tell; allowlist the host to debug.

Allow up to 24 hours before a newly marked key event shows in the standard
reports; Realtime and Preview are the immediate feedback loop.

## After the container is published

These two are GA4-side and cannot be done from GTM or the repo. Neither is
done yet.

1. **GA4 → Admin → Events → Mark as key event**, for `view_app_click` and
   `blog_article_click`. An event only appears in that list once it has been
   received at least once, so this cannot be done ahead of a deploy. (GA4
   renamed "conversions" to "key events" in 2024; "goals" was the Universal
   Analytics term and no longer exists — which is why #76's original title is
   the one thing about it that could not be implemented literally.)
2. **GA4 → Admin → Custom definitions → Custom dimensions.** Register
   `cta_location` and `article_slug` as **event-scoped** dimensions. Without
   this the events still count, but you cannot break them down by which CTA
   fired — which is most of the value.

## Adding another tracked CTA later

Add the `data-analytics-*` attributes to the markup, then repeat the GTM half
by hand: a Custom Event trigger on the new event name, a GA4 Event tag pointing
at `{{GA4 Measurement ID}}` with that trigger attached, and a Data Layer
Variable for any parameter name not already covered above.

## The newsletter form and `newsletter_signup`

`MailingListForm.vue` posts to the internal `POST /newsletter/subscribe` route
rather than calling Brevo from the browser (#426). `NewsletterController`
validates the address and makes the double opt-in call from PHP, reading the
API key from `config('services.brevo.key')`, which is populated by an
**unprefixed** `BREVO_API_KEY`.

The unprefixed name is the point. Laravel Mix inlines every `MIX_*` variable
into the **public** JS bundle at build time, so the previous
`MIX_SENDINBLUE_API_KEY` design would have published a live key to every
visitor the first time a production build ran with it set. Never reintroduce a
`MIX_`-prefixed secret, and never read an API key from `resources/js/`.

The component is enabled on the homepage, so `newsletter_signup` fires on a
successful proxied subscribe. It does **not** fire when the endpoint returns a
validation error (422), a throttle rejection (429), or an upstream failure
(502) — the event tracks confirmed submissions, not attempts.

The list and template identifiers live in `config/services.php` alongside the
key, and the double opt-in `redirectionUrl` is built with
`route('newsletter.confirmed')`, so the confirmation link cannot drift onto a
URL this application does not serve.
