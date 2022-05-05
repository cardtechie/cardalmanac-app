<?php

namespace App\Http\Controllers;

use App\Api\Facades\TradingCardApi;

/**
 * Class SetController
 */
class SetController extends Controller
{
    /**
     * Create a new controller instance.
     *
     * @return void
     */
    public function __construct()
    {
        //
    }

    /**
     * Show the application dashboard.
     *
     * @return \Illuminate\Contracts\Foundation\Application|\Illuminate\Contracts\View\Factory|\Illuminate\Contracts\View\View
     */
    public function index()
    {
        $sets = TradingCardApi::set()->list();
        //dump($sets);

        return view('app.sets', [
            'sets' => $sets,
        ]);
    }

    /**
     * Display the specified resource.
     *
     * @param  int  $id
     *
     * @return \Illuminate\Contracts\View\View|\Illuminate\View\View
     */
    public function show($id)
    {
        $set = TradingCardApi::set()->get($id);
        //dump($set);

        return view('app.set', [
            'set' => $set,
        ]);
    }
}
