<?php

namespace Tests\Feature;

use Tests\TestCase;

/**
 * Coverage for #76: homepage call-to-action tracking for the GA4 key events.
 *
 * The events themselves are pushed onto the GTM dataLayer by
 * resources/js/analytics.js; what PHP can guarantee is that the markup carries
 * the data-analytics-* attributes that listener keys off, so a template edit
 * cannot silently detach the tracking from the CTA.
 */
class HomepageAnalyticsTest extends TestCase
{
    public function test_the_view_app_cta_carries_its_analytics_attributes(): void
    {
        $html = view('layouts.marketing.home.app-teaser-component')->render();

        $this->assertStringContainsString('data-analytics-event="view_app_click"', $html);
        $this->assertStringContainsString('data-analytics-cta-location="homepage_app_teaser"', $html);
    }

    public function test_the_featured_post_cta_carries_its_analytics_attributes(): void
    {
        $html = view('layouts.marketing.home.blogpost-component')->render();

        $this->assertStringContainsString('data-analytics-event="blog_article_click"', $html);
        $this->assertStringContainsString('data-analytics-cta-location="homepage_featured_post"', $html);
        $this->assertStringContainsString('data-analytics-article-slug="introducing-card-almanac"', $html);
    }

    /**
     * The GTM container carries the GA4 configuration tag, so it must stay on
     * every layout — the dataLayer pushes are inert without it.
     */
    #[\PHPUnit\Framework\Attributes\DataProvider('layouts')]
    public function test_each_layout_loads_gtm_and_no_universal_analytics(string $layout): void
    {
        $source = file_get_contents(resource_path("views/layouts/{$layout}.blade.php"));

        $this->assertStringContainsString("@include('partials.head-gtm')", $source);
        $this->assertStringContainsString("@include('partials.body-gtm')", $source);

        // Universal Analytics stopped processing hits in July 2023; the dead
        // gtag snippet was removed in #76 and must not come back.
        $this->assertStringNotContainsString('partials.analytics', $source);
    }

    public static function layouts(): array
    {
        return [
            'app' => ['app'],
            'marketing default' => ['marketing/default'],
            'marketing home' => ['marketing/home'],
        ];
    }
}
