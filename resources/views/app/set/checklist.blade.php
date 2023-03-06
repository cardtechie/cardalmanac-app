@extends('layouts.app', [
    'title' => $set->name . ' Checklist',
])

@section('content')
    @include('app.set.tabs', ['setId' => $set->id, 'selected' => 'checklist'])

    <div>
        <ul>
        @foreach ($checklist as $section => $cards)
            <li class="font-bold">{{ $section }}</li>
            @foreach ($cards as $card)
                <li>{{ $card->name }}</li>
            @endforeach
        @endforeach
        </ul>
    </div>
@endsection
