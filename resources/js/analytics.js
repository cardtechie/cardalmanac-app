/**
 * Thin dataLayer wrapper for GA4-via-GTM.
 *
 * The site loads GA4 through the GTM container (partials/head-gtm.blade.php),
 * so nothing here talks to Google directly — we only push named events onto
 * the dataLayer. Each event still needs a matching Custom Event trigger and
 * GA4 Event tag in GTM before it reaches Analytics; see docs/ANALYTICS.md.
 */

/**
 * Push a named event onto the GTM dataLayer.
 *
 * Safe to call before GTM has loaded (the snippet seeds window.dataLayer) and
 * safe when GTM is blocked outright, so callers never need to guard.
 *
 * @param {string} event  GA4 event name, snake_case (e.g. "view_app_click").
 * @param {Object} params Additional GA4 event parameters.
 */
export function pushEvent(event, params = {}) {
  if (!event) {
    return;
  }

  window.dataLayer = window.dataLayer || [];
  window.dataLayer.push({ event, ...params });
}

/**
 * Convert a dataset key to the snake_case GA4 expects for event parameters.
 *
 * "ctaLocation" -> "cta_location"
 */
function toSnakeCase(key) {
  return key.replace(/[A-Z]/g, (char) => `_${char.toLowerCase()}`);
}

/**
 * Read the analytics payload off an element's data-analytics-* attributes.
 *
 * data-analytics-event="view_app_click" data-analytics-cta-location="hero"
 *   -> { event: "view_app_click", params: { cta_location: "hero" } }
 */
function readPayload(element) {
  const params = {};
  let event = null;

  Object.entries(element.dataset).forEach(([key, value]) => {
    if (!key.startsWith("analytics")) {
      return;
    }

    // Strip the "analytics" prefix and lower-case the now-leading letter.
    const name = key.slice("analytics".length);
    const normalized = name.charAt(0).toLowerCase() + name.slice(1);

    if (normalized === "event") {
      event = value;
      return;
    }

    params[toSnakeCase(normalized)] = value;
  });

  return { event, params };
}

/**
 * Bind a single delegated click listener that fires an event for any element
 * carrying data-analytics-event.
 *
 * Delegation means markup rendered later (Blade partials, Vue components) is
 * tracked without re-binding, and adding a tracked CTA is a markup-only change.
 *
 * Note: GA4 sends via navigator.sendBeacon, which survives the page unload
 * that follows a link click, so we deliberately do not delay navigation.
 */
export function bindAnalyticsEvents(root = document) {
  root.addEventListener("click", (clickEvent) => {
    const target = clickEvent.target.closest("[data-analytics-event]");

    if (!target) {
      return;
    }

    const { event, params } = readPayload(target);

    pushEvent(event, params);
  });
}

export default { pushEvent, bindAnalyticsEvents };
