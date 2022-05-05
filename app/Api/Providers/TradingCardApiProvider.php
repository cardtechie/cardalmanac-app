<?php

namespace App\Api\Providers;

use App\Api\TradingCardApi;
use Illuminate\Support\ServiceProvider;

/**
 * Class TradingCardApiProvider
 */
class TradingCardApiProvider extends ServiceProvider
{
    /**
     * Bootstrap the application services.
     *
     * @return void
     */
    public function boot()
    {
        //
    }

    /**
     * Register the application services.
     *
     * @return void
     */
    public function register()
    {
        $this->app->bind('trading-card-api', function () {
            return new TradingCardApi();
        });
    }
}
