@extends('layouts.app', [
    'title' => 'Sets',
])

@section('content')
    <div>
    @forelse ($sets as $set)
        @if ($loop->first)
            <ul>
        @endif
            <li><a href="{{ config('app.url') }}/app/sets/{{ $set->id }}">{{ $set->name }}</a> ({{ $set->genre()->name }})</li>
        @if ($loop->last)
            </ul>
        @endif
    @empty
        <p>No sets</p>
    @endforelse
    </div>
@endsection
