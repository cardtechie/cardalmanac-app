@extends('layouts.app', [
    'title' => $set->name,
])

@section('content')
    <div class="home main container max-w-sm max-w-md max-w-lg mx-auto mt-32">
        <h1>{{ $set->name }}</h1>
        <dl>
            <dt>Total Cards</dt>
            <dd>{{ $set->card_count }}</dd>

            <dt>Manufacturer</dt>
            <dd>{{ $set->manufacturer()->name }}</dd>

            <dt>Genre</dt>
            <dd>{{ $set->genre()->name }}</dd>

            <dt>Year</dt>
            <dd>{{ $set->year()->name }}</dd>
        </dl>
    </div>
@endsection
