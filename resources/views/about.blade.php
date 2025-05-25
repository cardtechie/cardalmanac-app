@extends('layouts.marketing.default', [
    'title' => 'About',
    'showPageTitle' => true,
])

@section('content')
    <div>
        <p class="mb-8">
            The goal of Card Almanac is to give each resource - card, set, player, team, manufacturer, brand, genre -
            it's own URL showing data pertinent to that resource.
        </p>
        <p class="mb-8">
            While there are other sites that provide similar data, I think it is possible to provide a more rich
            dataset for all resources. So much of this data can enhance how we collect cards. You'll notice the
            data currently provided is very basic. This will be the case for a while but over time more data will be added.
        </p>
        <p class="mb-8">
            Tools will be provided as well as data. These tools will make it easier to enhance your own websites.
            Application developers will be able to add to their customer experience so that the entire hobby can benefit.
        </p>
    </div>
@endsection
