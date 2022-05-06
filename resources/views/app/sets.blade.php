@extends('layouts.app', [
    'title' => 'Sets',
])

@section('content')
    <div class="mx-auto mt-32">
        <h2>Sets</h2>
    @forelse ($sets as $set)
        @if ($loop->first)
            <ul>
        @endif
            <li><a href="/sets/{{ $set->id }}">{{ $set->name }}</a></li>
        @if ($loop->last)
            </ul>
        @endif
    @empty
        <p>No sets</p>
    @endforelse
    </div>
@endsection
