@extends('layouts.marketing.home', [
    'title' => 'Home',
])

@section('content')
    <div class="row">
        <div class="col-md-12">
            <div class="text-center mb-12">
                <h2>Revolutionizing Trading Card Checklists</h2>
                <p>On a mission to change everything about checklists</p>
                <p class="mt-4"><a href="{{ route('app.index') }}" class="font-bold hover:underline">View app</a></p>
            </div>
        </div>
    </div>
    {{--  @include('layouts.marketing.home.mailing-list-component') --}}
@endsection
