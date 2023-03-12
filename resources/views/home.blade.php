@extends('layouts.marketing.home', [
    'title' => 'Home',
])

@section('content')
    <div class="row">
        <div class="col-md-12">
            <div class="text-center mb-12">
                <h2>Revolutionizing Trading Card Checklists</h2>
                <p>On a mission to change everything about checklists</p>
                <p class="mt-4"><a href="" class="font-bold hover:underline">View app</a></p>
            </div>
        </div>
    </div>
    <div class="row rounded-lg" style="background-color: #EBEBEB">
        <div class="col-md-12">
            <div class="text-center max-w-sm max-w-md max-w-lg mx-auto">
                <p class="font-medium pb-6 uppercase">Stay Tuned</p>
                <h2>Card Almanac is Launching Soon</h2>
                <p>
                    Subscribe to get updates in your inbox as the product is being developed.
                </p>
                <mailing-list-form></mailing-list-form>
            </div>
        </div>
    </div>
@endsection
