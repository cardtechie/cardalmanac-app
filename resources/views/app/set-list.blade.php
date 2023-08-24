@extends('layouts.app', [
    'title' => 'Sets',
])

@section('content')
    <div class="float-right">
        <span class="fa-2xl fa-border fa-pull-right fa-solid fa-grip-lines ml-2"></span>
        <span class="fa-2xl fa-border fa-pull-right fa-solid fa-grip ml-2"></span>
    </div>

    <div>
        <h3>List</h3>
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
