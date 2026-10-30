<?php

return [
    /*
    |--------------------------------------------------------------------------
    | API URL
    |--------------------------------------------------------------------------
    |
    | The URL of the API to connect with your application. This value is used
    | by the client to perform operations on the API.
    */
    'url' => env('TRADINGCARDAPI_URL', ''),

    /*
    |--------------------------------------------------------------------------
    | Toggle SSL Verification Mode
    |--------------------------------------------------------------------------
    |
    | Toggle SSL verification mode with a boolean value. This usually won't
    | need to be modified, unless you are working with a local API or any
    | other API instance without a valid SSL certificate.
    */
    'ssl_verify' => (bool) env('TRADINGCARDAPI_SSL_VERIFY', true),

    /*
    |--------------------------------------------------------------------------
    | Trading Card API Key
    |--------------------------------------------------------------------------
    |
    | A portal-issued API key (tc_live_... or tc_test_...) used to read the
    | catalog. It is sent as a bearer token and needs no OAuth round trip.
    | Add the key to your environment file so it doesn't get checked into
    | your code repo.
    */
    'api_key' => env('TRADINGCARDAPI_API_KEY', ''),

    /*
    |--------------------------------------------------------------------------
    | Authentication Type
    |--------------------------------------------------------------------------
    |
    | Pinned to 'api_key' rather than left to the SDK's auto-detection. The
    | SDK's own package config still reads TRADINGCARDAPI_CLIENT_ID and
    | TRADINGCARDAPI_CLIENT_SECRET, so an environment that kept those legacy
    | variables would otherwise silently switch back to OAuth, and a missing
    | key would fail through the OAuth path instead of the SDK's clear
    | "API key is required" error.
    */
    'auth_type' => 'api_key',
];
