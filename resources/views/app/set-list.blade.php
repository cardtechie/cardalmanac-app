@extends('layouts.app', [
    'title' => 'Sets',
])

@section('content')
    @if (isset($viewToggle) && $viewToggle)
        <x-set-view-toggle toggle-on="list" />
    @endif

    @isset ($genre)
        <h3>Genre: {{ $genre }}</h3>
    @endisset

    <div class="mt-8">
    @forelse ($sets as $set)
        @if ($loop->first)
            <ul>
        @endif
            <li>
                <a href="{{ route('app.set', ['id' => $set->id, 'name' => str()->slug($set->name)]) }}">{{ $set->name }}</a>
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
