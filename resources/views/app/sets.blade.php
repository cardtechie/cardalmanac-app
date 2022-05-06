@extends('layouts.app', [
    'title' => 'Sets',
])

@section('content')
    <div class="home main container mx-auto mt-32">
        <h1>Sets</h1>
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
