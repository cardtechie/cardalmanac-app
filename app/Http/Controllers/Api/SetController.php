<?php

namespace App\Http\Controllers\Api;

use App\Api\Facades\TradingCardApi;
use App\Http\Controllers\Controller;
use App\Http\Requests\SetRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Request as RequestFacade;

/**
 * Class SetController
 */
class SetController extends Controller
{
    /**
     * Retrieve a list of resources.
     *
     * @param  Request  $request
     *
     * @return JsonResponse
     */
    public function index(Request $request) : JsonResponse
    {
        $attributes = $request->all();
        $response = TradingCardApi::set()->list($attributes);

        return new JsonResponse($response);
    }

    /**
     * Retrieve a resource.
     *
     * @param string $id
     *
     * @return JsonResponse
     */
    public function get(string $id) : JsonResponse
    {
        $params = RequestFacade::all();
        $response = TradingCardApi::set()->get($id, $params);

        return new JsonResponse($response);
    }

    /**
     * Store a newly created resource in storage.
     *
     * @param  SetRequest  $request
     *
     * @return JsonResponse
     */
    public function create(SetRequest $request)
    {
        $attributes = $request->all();
        $response = TradingCardApi::set()->create($attributes);

        return new JsonResponse($response);
    }

    /**
     * Update a resource in storage.
     *
     * @param SetRequest $request
     * @param string $id
     *
     * @return JsonResponse
     */
    public function update(SetRequest $request, string $id)
    {
        $attributes = $request->all();
        $response = TradingCardApi::set()->update($id, $attributes);
        return new JsonResponse($response);
    }

    /**
     * Request to add missing cards to a set.
     *
     * @param string $id
     *
     * @return JsonResponse
     */
    public function addMissingCards($id)
    {
        $response = TradingCardApi::set()->addMissingCards($id);

        return new JsonResponse($response);
    }

    /**
     * Add a checklist requiring a custom payload that will be added to the api.
     *
     * @param Request $request
     * @param $id
     *
     * @return JsonResponse
     */
    public function addChecklist(Request $request, $id)
    {
        $lines = explode("\n", $request->getContent());

        $theRequest = [
            'json' => [
                'data' => [
                    'type' => 'checklist',
                    'attributes' => [
                        'lines' => $lines,
                    ],
                ],
            ],
        ];
        $response = TradingCardApi::set()->addChecklist($theRequest, $id);

        return new JsonResponse($response);
    }

    /**
     * Delete a set
     *
     * @param  string  $id
     *
     * @return JsonResponse
     */
    public function delete(string $id) : JsonResponse
    {
        $response = TradingCardApi::set()->delete($id);

        return (new JsonResponse($response))->setStatusCode(204);
    }
}
