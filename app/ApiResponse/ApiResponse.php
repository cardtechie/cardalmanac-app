<?php

namespace App\ApiResponse;

use App\ApiResponse\Http\Response\Factory;

/**
 * Trait ApiResponse
 */
trait ApiResponse
{
    /**
     * Get the response factory instance.
     *
     * @return \App\ApiResponse\Http\Response\Factory
     */
    protected function response()
    {
        return app(Factory::class);
    }
}
