@extends('layouts.app', [
    'title' => $set->name . ' Checklist',
])

@section('content')
    @include('app.set.tabs', ['setId' => $set->id, 'selected' => 'checklist'])

    <div>
        <ul>
        @foreach ($set->checklist() as $card)
            <li>{{ $card->name }}</li>
        @endforeach
        </ul>
    </div>
@endsection
