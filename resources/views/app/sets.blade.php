@extends('layouts.app', [
    'title' => 'Sets',
])

@section('content')
    <div>
    @forelse ($sets as $set)
        @if ($loop->first)
            <ul>
        @endif
            <li>
                <a href="{{ config('app.url') }}/app/sets/{{ $set->id }}/{{ str()->slug($set->name) }}">{{ $set->name }}</a>
            @if ($set->genre())
                ({{ $set->genre()->name }})
            @endif
            </li>
        @if ($loop->last)
            </ul>
        @endif
    @empty
        <p>No sets</p>
    @endforelse
    </div>
@endsection
