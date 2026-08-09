<?php

namespace App\Exceptions;

use CardTechie\TradingCardApiSdk\Exceptions\ResourceNotFoundException;
use CardTechie\TradingCardApiSdk\Exceptions\TradingCardApiException;
use Illuminate\Foundation\Exceptions\Handler as ExceptionHandler;
use Illuminate\Http\Request;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Throwable;

class Handler extends ExceptionHandler
{
    /**
     * A list of the exception types that are not reported.
     *
     * @var array<int, class-string<Throwable>>
     */
    protected $dontReport = [
        //
    ];

    /**
     * A list of the inputs that are never flashed for validation exceptions.
     *
     * @var array<int, string>
     */
    protected $dontFlash = [
        'current_password',
        'password',
        'password_confirmation',
    ];

    /**
     * Register the exception handling callbacks for the application.
     *
     * @return void
     */
    public function register()
    {
        $this->reportable(function (Throwable $e) {
            //
        });

        // A card that doesn't exist upstream is a 404, not a server fault.
        // Registered before the catch-all below, which it extends.
        $this->renderable(function (ResourceNotFoundException $e, Request $request) {
            if ($request->expectsJson()) {
                return response()->json(['message' => 'Not found.'], 404);
            }

            return $this->renderHttpException(new NotFoundHttpException($e->getMessage(), $e));
        });

        // Every API call authenticates first, so one bad credential or a brief
        // network blip would otherwise turn every content page into a blank 500.
        // Degrade to a real page instead, keeping nav and marketing usable.
        $this->renderable(function (TradingCardApiException $e, Request $request) {
            if ($request->expectsJson()) {
                return response()->json(
                    ['message' => 'The card data service is temporarily unavailable.'],
                    503
                );
            }

            return response()->view('errors.api-unavailable', [
                'title' => 'Temporarily Unavailable',
            ], 503);
        });
    }
}
