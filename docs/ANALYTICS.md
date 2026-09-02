# Analytics

Card Almanac measures traffic with **GA4, loaded through Google Tag Manager**.
The GTM container snippet lives in `resources/views/partials/head-gtm.blade.php`
(and its `<noscript>` half in `partials/body-gtm.blade.php`), and is included by
every layout. The GA4 configuration tag itself lives inside the GTM container,
not in this repo — there is deliberately no `gtag.js` snippet in the codebase.

> The former `partials/analytics.blade.php` hard-coded the Universal Analytics
> property `UA-26467066-4`. Universal Analytics stopped processing hits on
> 1 July 2023 and the properties were deleted in 2024, so that snippet was
> shipping a request that went nowhere. It was removed in #76.

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
5. **GA4 → Admin → Events.** Once an event has been received at least once it
   appears in the list — toggle **Mark as key event**. (GA4 renamed
   "conversions" to "key events" in 2024; "goals" was the Universal Analytics
   term and no longer exists.)
6. **GA4 → Admin → Custom definitions → Custom dimensions.** Register
   `cta_location` and `article_slug` as event-scoped dimensions, or they will
   not be queryable in reports.

Note that `newsletter_signup` is deliberately **not** in the import file — it
cannot fire until the mailing list form is re-enabled (see the caveat below).

### Verifying in GTM Preview

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

### Adding another tracked CTA later

Add the `data-analytics-*` attributes to the markup, then repeat the GTM half
by hand: a Custom Event trigger on the new event name, a GA4 Event tag pointing
at `{{GA4 Measurement ID}}` with that trigger attached, and a Data Layer
Variable for any parameter name not already covered above.

## Caveat: the newsletter form is not production-ready

`resources/js/api/send-in-blue/index.api.js` reads the Brevo (Sendinblue) API
key from `process.env.MIX_SENDINBLUE_API_KEY`. Laravel Mix inlines `MIX_*`
variables into the **public** JS bundle at build time, which means:

- If a production build ever runs with that variable set, the API key is
  readable by anyone who views the bundle.
- The current production build ran **without** it, so the key is not exposed —
  but the header is sent as `undefined` and Brevo rejects the request. The form
  would show its generic failure message to every visitor.

Re-enabling the mailing list therefore needs a server-side proxy route that
holds the key in `config/services.php` and calls Brevo from PHP. Until then the
component stays commented out and `newsletter_signup` will not fire.
