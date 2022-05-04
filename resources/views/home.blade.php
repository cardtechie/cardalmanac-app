@extends('layouts.marketing', [
    'title' => 'Home',
])

@section('content')
    <div class="home main text-center container max-w-sm max-w-md max-w-lg mx-auto mt-32">
        <p class="font-medium pb-6 uppercase">Stay Tuned</p>
        <h2>Card Almanac is Launching Soon</h2>
        <p>
            Subscribe to get updates in your inbox as the product is being developed.
        </p>
        <mailing-list-form></mailing-list-form>

        <div class="mt-24">
            <a href="https://twitter.com/cardalmanac">
                <span class="fab fa-twitter"></span>
                Follow Card Almanac on Twitter
            </a>
        </div>
    </div>
@endsection
