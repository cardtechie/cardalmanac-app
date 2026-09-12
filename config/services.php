<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'mailgun' => [
        'domain' => env('MAILGUN_DOMAIN'),
        'secret' => env('MAILGUN_SECRET'),
        'endpoint' => env('MAILGUN_ENDPOINT', 'api.mailgun.net'),
        'scheme' => 'https',
    ],

    'postmark' => [
        'token' => env('POSTMARK_TOKEN'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Brevo (formerly Sendinblue)
    |--------------------------------------------------------------------------
    |
    | Credentials for the newsletter double opt-in call, which is made from
    | PHP by App\Http\Controllers\NewsletterController.
    |
    | BREVO_API_KEY is deliberately *not* MIX_-prefixed. Laravel Mix inlines
    | every MIX_* variable into the public JS bundle at build time, so a
    | prefixed name would publish a live API key to every visitor (#426).
    | Never rename this to MIX_BREVO_API_KEY, and never read it from
    | resources/js/.
    |
    | The list and template identifiers are not secrets and are stable across
    | environments, so they are literal defaults rather than env() reads.
    |
    */

    'brevo' => [
        'key' => env('BREVO_API_KEY'),
        'base_url' => env('BREVO_BASE_URL', 'https://api.brevo.com/v3'),
        'list_ids' => [
            4, // CardTechie Notifications
        ],
        'template_id' => 1,
    ],

    /*
    |--------------------------------------------------------------------------
    | Product Calls To Action
    |--------------------------------------------------------------------------
    |
    | Contextual CTAs rendered by resources/views/partials/product-cta.blade.php
    | on high-intent pages (set details, set checklist). The partial iterates
    | this list, so adding another product CTA is a config change and touches
    | no markup. Copy lives here rather than in Blade so it is editable without
    | a view change; only the toggle and destination URL are env-backed.
    |
    */

    'products' => [
        'ctas' => [
            'api' => [
                'enabled' => (bool) env('PRODUCT_CTA_API_ENABLED', true),
                'heading' => 'Want this data in your app?',
                'body' => 'The Trading Card API serves the same set and checklist data behind Card Almanac, ready to drop into your own project.',
                'url' => env('PRODUCT_CTA_API_URL', 'https://tradingcardapi.com/pricing'),
                'link_text' => 'Check out the Trading Card API',
            ],
        ],
    ],

];
