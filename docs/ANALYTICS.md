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

## Configuring the goal in GA4 — manual, one time per event

Pushing to the dataLayer is only half the job. A dataLayer event does **not**
reach GA4 on its own: the GTM container has to listen for it and forward it.
This part is UI work in your Google account and cannot be done from the repo.

For each event above:

1. **GTM → Triggers → New → Custom Event.** Set _Event name_ to the exact
   string (e.g. `view_app_click`). Fires on: All Custom Events.
2. **GTM → Tags → New → Google Analytics: GA4 Event.** Point it at your GA4
   configuration tag / measurement ID, set _Event Name_ to the same string, and
   attach the trigger from step 1.
3. Add the parameters under _Event Parameters_. Each one needs a **Data Layer
   Variable** in GTM (Variables → New → Data Layer Variable) whose name matches
   the pushed key exactly — `cta_location`, `article_slug`.
4. **Preview** the container, click the CTA on the site, and confirm the tag
   fires and the parameters are populated.
5. **Submit / publish** the container version.
6. **GA4 → Admin → Events.** Once the event has been received at least once it
   appears in the list; toggle **Mark as key event**. (GA4 renamed
   "conversions" to "key events" in 2024; "goals" was the Universal Analytics
   term and no longer exists.)

Custom parameters also need registering under **GA4 → Admin → Custom
definitions → Custom dimensions** before they are queryable in reports.

Allow up to 24 hours before a newly marked key event is populated in the
standard reports; use **Realtime** and GTM Preview for immediate verification.

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
