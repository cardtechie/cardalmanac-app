<?php

return [

    'url' => env('TRADINGCARDAPI_URL', ''),

    'ssl_verify' => (bool) env('TRADINGCARDAPI_SSL_VERIFY', true),

    'client_id' => env('TRADINGCARDAPI_CLIENT_ID', ''),

    'client_secret' => env('TRADINGCARDAPI_CLIENT_SECRET', ''),
];
