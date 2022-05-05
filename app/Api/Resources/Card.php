<?php

namespace App\Api\Resources;

use App\Api\Resources\Traits\ApiRequest;
use App\Api\Response;
use App\Models\Card as CardModel;
use GuzzleHttp\Client;

/**
 * Class Card
 */
class Card
{
    use ApiRequest;

    /**
     * Card constructor.
     *
     * @param Client $client
     */
    public function __construct(Client $client)
    {
        $this->client = $client;
    }

    /**
     * Create the card with the passed in attributes
     *
     * @param array $attributes
     * @param array $relationships
     *
     * @return CardModel
     *
     * @throws \Psr\SimpleCache\InvalidArgumentException
     */
    public function create(array $attributes = [], array $relationships = []) : CardModel
    {
        $request = [
            'json' => [
                'data' => [
                    'type' => 'cards',
                ],
            ],
        ];

        if (count($attributes)) {
            $request['json']['data']['attributes'] = $attributes;
        }

        if (count($relationships)) {
            $request['json']['data']['relationships'] = $relationships;
        }

        $response = $this->makeRequest('/cards', 'POST', $request);
        $formattedResponse = new Response(json_encode($response));
        return $formattedResponse->mainObject;
    }

    /**
     * Retrieve a set by ID
     *
     * @param string $id
     *
     * @return CardModel
     *
     * @throws \Psr\SimpleCache\InvalidArgumentException
     */
    public function get(string $id) : CardModel
    {
        $includes = 'set,oncard,attributes';
        $url = sprintf('/cards/%s?include=%s', $id, $includes);
        $response = $this->makeRequest($url);
        $formattedResponse = new Response(json_encode($response));
        return $formattedResponse->mainObject;
    }

    /**
     * Update the set
     *
     * @param string $id
     * @param array $attributes
     * @param array $relationships
     *
     * @return CardModel
     *
     * @throws \Psr\SimpleCache\InvalidArgumentException
     */
    public function update(string $id, array $attributes = [], array $relationships = []) : CardModel
    {
        $url = sprintf('/cards/%s', $id);
        $request = [
            'json' => [
                'data' => [
                    'type' => 'cards',
                    'id' => $id,
                ],
            ],
        ];

        if (count($attributes)) {
            $request['json']['data']['attributes'] = $attributes;
        }

        if (count($relationships)) {
            $request['json']['data']['relationships'] = $relationships;
        }

        $response = $this->makeRequest($url, 'PUT', $request);
        $formattedResponse = new Response(json_encode($response));
        return $formattedResponse->mainObject;
    }

    /**
     * Delete a card
     *
     * @param string $id
     *
     * @return void
     *
     * @throws \Psr\SimpleCache\InvalidArgumentException
     */
    public function delete(string $id) : void
    {
        $url = '/cards/' . $id;
        $this->makeRequest($url, 'DELETE');
    }
}
