@extends('layouts.app', [
    'title' => $set->name,
])

@section('content')
    <div class="mx-auto mt-32">
        <h2>{{ $set->name }}</h2>
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
