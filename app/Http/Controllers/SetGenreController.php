<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class SetGenreController extends Controller
{
    /**
     * Handle the incoming request.
     */
    public function __invoke(Request $request, string $genreId)
    {
        $sets = tradingcardapi()->set()->list([
            'genre' => $genreId,
        ]);

        return view('app.set-list', [
            'genre' => 'Baseball',
            'sets' => $sets,
        ]);
    }
}
