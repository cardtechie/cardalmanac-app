@extends('layouts.app', [
    'title' => 'Sets',
])

@section('content')
<x-set-view-toggle toggle-on="group" />

<div class="grid md:grid-cols-3">
    @forelse ($list as $entry)
    <div class="mb-6">
        <h3 class="mb-2">{{ $entry['genre']->name }}</h3>
        <ul>
        @forelse ($entry['sets']->toArray()['data'] as $set)
            <li>
                <a href="{{ route('app.set', ['id' => $set->id, 'name' => str()->slug($set->name)]) }}">{{ $set->name }}</a>
            </li>
        @empty
            <li>No sets for this genre</li>
        @endforelse
        </ul>

        <div class="pt-2 text-sm">
            <a href="{{ route('app.set.genre', ['genre' => $entry['genre']->id]) }}">Browse {{ $entry['genre']->name }} sets &raquo;</a>
        </div>
    </div>
    @empty
        <p>No sets</p>
    @endforelse
</div>
@endsection
