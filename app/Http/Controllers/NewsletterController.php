<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Server-side proxy for the newsletter double opt-in (#426).
 *
 * The Brevo API key used to be attached to the request in the browser, from
 * `process.env.MIX_SENDINBLUE_API_KEY`. Laravel Mix inlines every MIX_*
 * variable into the public JS bundle, so setting that variable for a
 * production build would have published a live key to every visitor. The call
 * is made from PHP instead, with the key read from config/services.php and
 * never sent to the client.
 */
class NewsletterController extends Controller
{
    /**
     * Subscribe an address to the newsletter via Brevo's double opt-in flow.
     */
    public function subscribe(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email:rfc,dns', 'max:254'],
        ]);

        $key = config('services.brevo.key');

        // Fail closed rather than sending an `api-key: ` header Brevo will
        // reject. An unconfigured deploy is a deployment problem, not
        // something to surface to the visitor as a partial success.
        if (blank($key)) {
            Log::warning('Newsletter subscribe attempted with no Brevo API key configured.');

            return $this->failure();
        }

        $endpoint = rtrim((string) config('services.brevo.base_url'), '/')
            .'/contacts/doubleOptinConfirmation';

        try {
            $response = Http::withHeaders([
                'api-key' => $key,
                'accept' => 'application/json',
            ])
                // This call sits on the critical path of a public page, so it
                // gets an explicit budget rather than the client's 30s
                // default: a slow Brevo must not pin a PHP-FPM worker.
                ->connectTimeout(5)
                ->timeout(10)
                ->post($endpoint, [
                    'email' => $validated['email'],
                    'includeListIds' => config('services.brevo.list_ids'),
                    'templateId' => config('services.brevo.template_id'),
                    // Built from the route so the confirmation link can never
                    // drift onto a URL this application does not serve, which
                    // is how it came to 404 in production.
                    'redirectionUrl' => route('newsletter.confirmed'),
                ]);
        } catch (Throwable $e) {
            // Pass the Throwable itself, not just its message: Monolog's
            // normalizer expands an exception in the context into its class,
            // code, file, line and stack trace, which is what makes a
            // production failure diagnosable.
            Log::warning('Newsletter subscribe request to Brevo failed.', [
                'exception' => $e,
            ]);

            return $this->failure();
        }

        if ($response->failed()) {
            Log::warning('Brevo rejected a newsletter subscribe request.', [
                'status' => $response->status(),
            ]);

            return $this->failure();
        }

        return response()->json(['status' => 'ok']);
    }

    /**
     * The landing page Brevo redirects to once the opt-in is confirmed.
     *
     * @return \Illuminate\Contracts\View\View
     */
    public function confirmed()
    {
        return view('newsletter.confirmed');
    }

    /**
     * A generic failure body. It deliberately carries no upstream detail —
     * nothing about the key or the Brevo response reaches the browser.
     */
    private function failure(): JsonResponse
    {
        return response()->json([
            'status' => 'error',
            'message' => 'Unable to add your email address to the mailing list.',
        ], 502);
    }
}
