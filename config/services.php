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
