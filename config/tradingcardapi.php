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
    | Do not supply a client ID or secret alongside it: when both are set the
    | SDK authenticates with OAuth instead of the key. Add the key to your
    | environment file so it doesn't get checked into your code repo.
    */
    'api_key' => env('TRADINGCARDAPI_API_KEY', ''),
];
