<?php

namespace App\ApiResponse\Http\Response;

use App\ApiResponse\Http\Response;

/**
 * Class Factory
 */
class Factory
{
    /**
     * Respond with a created response and associate a location if provided.
     *
     * @param null|string $location
     * @param null|string $content
     *
     * @return \App\ApiResponse\Http\Response
     */
    public function created($location = null, $content = null)
    {
        $response = new Response($content);
        $response->setStatusCode(Response::HTTP_CREATED);

        if (!is_null($location)) {
            $response->header('Location', $location);
        }

        return $response;
    }
}
