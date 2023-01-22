<?php

namespace App\Http\Controllers;

use Illuminate\Support\Str;

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
     *
     * @throws \Psr\SimpleCache\InvalidArgumentException
     */
    public function index()
    {
        $sets = tradingcardapi()->set()->list([
            'include' => 'genre',
        ]);

        return view('app.sets', [
            'sets' => $sets,
        ]);
    }

    /**
     * Display the specified resource.
     *
     * @param string $id
     * @param string $name
     *
     * @return \Illuminate\Contracts\Foundation\Application|\Illuminate\Http\RedirectResponse|\Illuminate\Routing\Redirector
     *
     * @throws \Psr\SimpleCache\InvalidArgumentException
     */
    public function show(string $id, string $name = '')
    {
        $set = tradingcardapi()->set()->get($id);

        if (empty($name)) {
            $url = sprintf('/app/sets/%s/%s', $id, Str::slug($set->name));
            return redirect($url);
        }

        return view('app.set.details', [
            'set' => $set,
        ]);
    }

    public function checklist(string $id)
    {
        $set = tradingcardapi()->set()->get($id);

        return view('app.set.checklist', [
            'set' => $set,
        ]);
    }

    public function subsets(string $id)
    {
        $set = tradingcardapi()->set()->get($id);

        return view('app.set.subsets', [
            'set' => $set,
        ]);
    }
}
