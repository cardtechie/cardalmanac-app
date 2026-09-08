<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Coverage for #426: the Brevo newsletter call moved out of the browser and
 * behind a rate-limited Laravel route, so no API key can reach the JS bundle.
 */
class NewsletterSubscribeTest extends TestCase
{
    private const KEY = 'test-brevo-key-must-not-leak';

    private const BASE_URL = 'https://api.brevo.test/v3';

    /**
     * The `dns` rule requires a domain that actually accepts mail, so the
     * usual example.com will not do: it publishes an RFC 7505 "null MX",
     * which is an explicit declaration that it accepts none.
     */
    private const VALID_EMAIL = 'subscriber@gmail.com';

    protected function setUp(): void
    {
        parent::setUp();

        Config::set('services.brevo.key', self::KEY);
        Config::set('services.brevo.base_url', self::BASE_URL);
        Config::set('services.brevo.list_ids', [4]);
        Config::set('services.brevo.template_id', 1);
    }

    private function endpoint(): string
    {
        return self::BASE_URL.'/contacts/doubleOptinConfirmation';
    }

    public function test_a_missing_email_is_rejected_without_calling_brevo(): void
    {
        Http::fake();

        $response = $this->postJson('/newsletter/subscribe', []);

        $response->assertStatus(422);
        Http::assertNothingSent();
    }

    public function test_a_malformed_email_is_rejected_without_calling_brevo(): void
    {
        Http::fake();

        $response = $this->postJson('/newsletter/subscribe', ['email' => 'not-an-email']);

        $response->assertStatus(422);
        Http::assertNothingSent();
    }

    public function test_a_valid_email_is_proxied_to_brevo_with_the_configured_payload(): void
    {
        Http::fake([$this->endpoint() => Http::response(['messageId' => 1], 201)]);

        $response = $this->postJson('/newsletter/subscribe', ['email' => self::VALID_EMAIL]);

        $response->assertOk();
        $response->assertJson(['status' => 'ok']);

        Http::assertSentCount(1);
        Http::assertSent(function ($request) {
            return $request->url() === $this->endpoint()
                && $request->method() === 'POST'
                && $request->hasHeader('api-key', self::KEY)
                && $request['email'] === self::VALID_EMAIL
                && $request['includeListIds'] === [4]
                && $request['templateId'] === 1
                && $request['redirectionUrl'] === route('newsletter.confirmed');
        });
    }

    /**
     * The whole point of the change: the key is used server-side and never
     * travels back to the browser.
     */
    public function test_the_api_key_never_reaches_the_response_body(): void
    {
        Http::fake([$this->endpoint() => Http::response(['messageId' => 1], 201)]);

        $response = $this->postJson('/newsletter/subscribe', ['email' => self::VALID_EMAIL]);

        $this->assertStringNotContainsString(self::KEY, $response->getContent());
        $this->assertStringNotContainsString(self::KEY, json_encode($response->headers->all()));
    }

    public function test_a_brevo_failure_yields_a_json_error_rather_than_an_exception_page(): void
    {
        Http::fake([$this->endpoint() => Http::response(['message' => 'bad request'], 400)]);

        $response = $this->postJson('/newsletter/subscribe', ['email' => self::VALID_EMAIL]);

        $response->assertStatus(502);
        $response->assertJson(['status' => 'error']);
        $this->assertStringNotContainsString(self::KEY, $response->getContent());
    }

    public function test_a_brevo_server_error_also_yields_a_json_error(): void
    {
        Http::fake([$this->endpoint() => Http::response('', 500)]);

        $response = $this->postJson('/newsletter/subscribe', ['email' => self::VALID_EMAIL]);

        $response->assertStatus(502);
        $response->assertJson(['status' => 'error']);
    }

    public function test_an_unset_api_key_fails_closed_without_sending_a_request(): void
    {
        Config::set('services.brevo.key', null);
        Http::fake();

        $response = $this->postJson('/newsletter/subscribe', ['email' => self::VALID_EMAIL]);

        $response->assertStatus(502);
        Http::assertNothingSent();
    }

    public function test_the_endpoint_is_rate_limited(): void
    {
        Http::fake();

        // Deliberately invalid so no outbound call or DNS lookup is needed:
        // the throttle middleware runs ahead of validation, so the limiter is
        // exercised either way.
        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/newsletter/subscribe', ['email' => 'not-an-email'])
                ->assertStatus(422);
        }

        $this->postJson('/newsletter/subscribe', ['email' => 'not-an-email'])
            ->assertStatus(429);

        Http::assertNothingSent();
    }

    public function test_the_confirmation_landing_page_exists_and_renders(): void
    {
        $response = $this->get('/complete-newsletter-signup');

        $response->assertOk();
        $response->assertViewIs('newsletter.confirmed');
        $response->assertSee('Newsletter Signup Complete');
    }

    /**
     * The redirect Brevo sends confirmed subscribers to is built from the
     * route, so it can never point at a URL this application does not serve —
     * which is how it came to 404 in production.
     */
    public function test_the_confirmation_route_is_the_redirect_target(): void
    {
        $this->assertSame(url('/complete-newsletter-signup'), route('newsletter.confirmed'));
    }

    /**
     * Guards the acceptance criterion directly at the source level: no
     * MIX_-prefixed secret, and no Brevo client, anywhere in resources/js/.
     */
    public function test_no_browser_side_brevo_client_remains(): void
    {
        $this->assertDirectoryDoesNotExist(resource_path('js/api/send-in-blue'));

        $sources = [];
        $iterator = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator(resource_path('js'), \FilesystemIterator::SKIP_DOTS)
        );

        foreach ($iterator as $file) {
            if ($file->isFile()) {
                $sources[$file->getPathname()] = file_get_contents($file->getPathname());
            }
        }

        $this->assertNotEmpty($sources, 'Expected to scan at least one file under resources/js.');

        foreach ($sources as $path => $contents) {
            $this->assertStringNotContainsString('MIX_SENDINBLUE_API_KEY', $contents, $path);
            $this->assertStringNotContainsString('API_KEY', $contents, $path);
            $this->assertStringNotContainsString('api.sendinblue.com', $contents, $path);
            $this->assertStringNotContainsString('api.brevo.com', $contents, $path);
        }
    }
}
