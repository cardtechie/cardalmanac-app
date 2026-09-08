@extends('layouts.marketing.default', [
    'title' => 'Newsletter Signup Complete',
    'showPageTitle' => true,
])

@section('content')
    <div>
        <p class="mb-8">
            Your subscription is confirmed. You'll start receiving Card Almanac updates, news, and
            release notes in your inbox as the product is developed.
        </p>
        <p class="mb-8">
            Every email includes an unsubscribe link, so you can stop at any time.
        </p>
        <p class="mb-8">
            <a href="{{ route('home') }}">Return to the homepage</a>
        </p>
    </div>
@endsection
