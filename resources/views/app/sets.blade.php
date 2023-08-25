@extends('layouts.app', [
    'title' => 'Sets',
])

@section('content')
    <x-set-view-toggle toggle-on="group" />

    @forelse ($list as $entry)
    <div>
        <h3>{{ $entry['genre']->name }}</h3>
        <ul>
        @forelse ($entry['sets']->toArray()['data'] as $set)
            <li>
                <a href="{{ route('app.set', ['id' => $set->id, 'name' => str()->slug($set->name)]) }}">{{ $set->name }}</a>
            </li>
        @empty
            <p>No sets for this genre</p>
        @endforelse
        </ul>
    </div>
    @empty
        <p>No sets</p>
    @endforelse
@endsection
