<?php

namespace App\Api\Resources;

use App\Api\Resources\Traits\ApiRequest;
use App\Api\Response;
use GuzzleHttp\Client;
use Illuminate\Support\Collection;

/**
 * Class Playerteam
 */
class Playerteam
{
    use ApiRequest;

    /**
     * Playerteam constructor.
     *
     * @param Client $client
     */
    public function __construct(Client $client)
    {
        $this->client = $client;
    }

    /**
     * Retrieve a playerteam by player and/or team id
     *
     * @param array $params
     *
     * @return Collection
     *
     * @throws \Psr\SimpleCache\InvalidArgumentException
     */
    public function getList(array $params = []) : Collection
    {
        $query = http_build_query($params);
        $url = sprintf('/playerteams?%s', $query);
        $response = $this->makeRequest($url);

        return Response::parse(json_encode($response));
    }
}
