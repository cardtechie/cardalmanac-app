<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\File;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/**
 * Coverage for #370: a config-driven Trading Card API call-to-action on the
 * set detail and set checklist pages.
 *
 * The partial is rendered directly rather than through the set routes:
 * SetController::show() and ::checklist() both call the Trading Card API SDK
 * (and show() redirects when the slug is absent), so route-level tests would
 * need heavy SDK mocking without covering anything extra about this change.
 */
class ProductCtaTest extends TestCase
{
    /**
     * Build a single CTA entry, overriding any key.
     */
    private function cta(array $overrides = []): array
    {
        return array_merge([
            'enabled' => true,
            'heading' => 'Want this data in your app?',
            'body' => 'The same set and checklist data, ready for your project.',
            'url' => 'https://tradingcardapi.com/pricing',
            'link_text' => 'Check out the Trading Card API',
        ], $overrides);
    }

    private function renderPartial(): string
    {
        return view('partials.product-cta')->render();
    }

    public function test_an_enabled_entry_renders_its_copy_and_configured_url(): void
    {
        Config::set('services.products.ctas', ['api' => $this->cta()]);

        $html = $this->renderPartial();

        $this->assertStringContainsString('Want this data in your app?', $html);
        $this->assertStringContainsString('The same set and checklist data, ready for your project.', $html);
        $this->assertStringContainsString('Check out the Trading Card API', $html);
        $this->assertStringContainsString('href="https://tradingcardapi.com/pricing"', $html);
        $this->assertStringContainsString('rel="noopener"', $html);
    }

    public function test_the_url_is_driven_by_config_not_hardcoded(): void
    {
        Config::set('services.products.ctas', [
            'api' => $this->cta(['url' => 'https://example.test/custom-signup']),
        ]);

        $html = $this->renderPartial();

        $this->assertStringContainsString('href="https://example.test/custom-signup"', $html);
        $this->assertStringNotContainsString('tradingcardapi.com', $html);
    }

    public function test_a_disabled_entry_renders_nothing(): void
    {
        Config::set('services.products.ctas', ['api' => $this->cta(['enabled' => false])]);

        $this->assertSame('', trim($this->renderPartial()));
    }

    public function test_an_entry_without_a_url_renders_nothing_rather_than_a_dead_link(): void
    {
        Config::set('services.products.ctas', ['api' => $this->cta(['url' => ''])]);

        $this->assertSame('', trim($this->renderPartial()));
    }

    public function test_an_empty_cta_list_renders_nothing_and_does_not_error(): void
    {
        Config::set('services.products.ctas', []);

        $this->assertSame('', trim($this->renderPartial()));
    }

    public function test_a_missing_products_config_renders_nothing_and_does_not_error(): void
    {
        Config::set('services.products', null);

        $this->assertSame('', trim($this->renderPartial()));
    }

    public function test_no_mcp_call_to_action_is_rendered(): void
    {
        // Guards the #370/#409 split: the MCP CTA ships separately, once the
        // MCP server is ready for release.
        $html = strtolower($this->renderPartial());

        $this->assertStringNotContainsString('mcp', $html);
        $this->assertStringNotContainsString('model context protocol', $html);
    }

    public function test_the_shipped_config_contains_exactly_one_cta_keyed_api(): void
    {
        $ctas = config('services.products.ctas');

        $this->assertIsArray($ctas);
        $this->assertSame(['api'], array_keys($ctas));

        $api = $ctas['api'];

        foreach (['enabled', 'heading', 'body', 'url', 'link_text'] as $key) {
            $this->assertArrayHasKey($key, $api);
        }

        $this->assertIsBool($api['enabled']);
        $this->assertIsString($api['url']);
        $this->assertNotSame('', $api['url']);

        // Assert the env wiring rather than the env-resolved value: an
        // environment that overrides PRODUCT_CTA_API_* must not fail the suite,
        // but the shipped defaults (enabled, pointing at the pricing page) are
        // still pinned for the un-overridden case.
        $this->assertSame((bool) env('PRODUCT_CTA_API_ENABLED', true), $api['enabled']);
        $this->assertSame(env('PRODUCT_CTA_API_URL', 'https://tradingcardapi.com/pricing'), $api['url']);
    }

    #[DataProvider('viewsThatIncludeTheCta')]
    public function test_the_page_includes_the_cta_partial(string $viewPath): void
    {
        $this->assertStringContainsString(
            "@include('partials.product-cta')",
            File::get(resource_path($viewPath)),
            "{$viewPath} should include the product CTA partial."
        );
    }

    public static function viewsThatIncludeTheCta(): array
    {
        return [
            'set details' => ['views/app/set/details.blade.php'],
            'set checklist' => ['views/app/set/checklist.blade.php'],
        ];
    }
}
