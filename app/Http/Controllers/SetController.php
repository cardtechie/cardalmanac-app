<?php

namespace App\Http\Controllers;

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
     * Show the set dashboard.
     *
     * @return \Illuminate\Contracts\Foundation\Application|\Illuminate\Contracts\View\Factory|\Illuminate\Contracts\View\View
     *
     * @throws \Psr\SimpleCache\InvalidArgumentException
     */
    public function index()
    {
        $list = [];
        $index = 0;

        $genres = tradingcardapi()->genre()->list();

        foreach ($genres as $genre) {
            $sets = tradingcardapi()->set()->list([
                'include' => 'genre',
                'genre' => $genre->id,
                'limit' => 10,
                'order_by' => 'created_at',
            ]);

            if ($sets->count()) {
                $list[$index]['genre'] = $genre;
                $list[$index]['sets'] = $sets;
                $index++;
            }
        }

        return view('app.sets', [
            'list' => $list,
        ]);
    }

    /**
     * Show a list of sets
     *
     * @return \Illuminate\Contracts\Foundation\Application|\Illuminate\Contracts\View\Factory|\Illuminate\Contracts\View\View|\Illuminate\Foundation\Application
     *
     * @throws \Psr\SimpleCache\InvalidArgumentException
     */
    public function list()
    {
        $sets = tradingcardapi()->set()->list([
            'include' => 'genre',
        ]);

        return view('app.set-list', [
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
        $set = tradingcardapi()->set()->get($id, [
            'include' => 'genre,manufacturer,brand,year',
        ]);

        if (empty($name)) {
            return redirect()
                ->route('app.set', ['id' => $set->id, 'name' => str()->slug($set->name)])
                ->setStatusCode(301);
        }

        return view('app.set.details', [
            'set' => $set,
        ]);
    }

    public function checklist(string $id)
    {
        $set = tradingcardapi()->set()->get($id, [
            'include' => 'checklist',
        ]);

        $checklist = [];
        foreach($set->checklist() as $card) {
            $checklist[$card->section][] = $card;
        }

        return view('app.set.checklist', [
            'set' => $set,
            'checklist' => $checklist,
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
