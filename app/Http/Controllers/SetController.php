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

        return view('app.sets', [
            'sets' => $sets,
        ]);
    }

    /**
     * Display the specified resource.
     *
     * @param  string  $id
     *
     * @return \Illuminate\Contracts\View\View|\Illuminate\View\View
     */
    public function show(string $id)
    {
        $set = TradingCardApi::set()->get($id);

        return view('app.set.details', [
            'set' => $set,
        ]);
    }

    public function checklist(string $id)
    {
        $set = TradingCardApi::set()->get($id);

        return view('app.set.checklist', [
            'set' => $set,
        ]);
    }

    public function subsets(string $id)
    {
        $set = TradingCardApi::set()->get($id);

        return view('app.set.subsets', [
            'set' => $set,
        ]);
    }
}
