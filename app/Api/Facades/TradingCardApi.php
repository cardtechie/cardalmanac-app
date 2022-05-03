<?php

namespace App\Api\Facades;

use Illuminate\Support\Facades\Facade;

/**
 * Class TradingCardApiFacade
 */
class TradingCardApi extends Facade
{
    /**
     * Get the registered name of the component.
     *
     * @return string
     *
     * @throws \RuntimeException
     */
    protected static function getFacadeAccessor()
    {
        return 'trading-card-api';
    }
}
