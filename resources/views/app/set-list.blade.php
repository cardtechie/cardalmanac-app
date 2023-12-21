@extends('layouts.app', [
    'title' => isset($title) ? $title : 'Checklists',
])

@section('content')
    @if (isset($viewToggle) && $viewToggle)
        <x-set-view-toggle toggle-on="list" />
    @endif

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
        <p>No checklists have been published.</p>
    @endforelse
    </div>
@endsection
