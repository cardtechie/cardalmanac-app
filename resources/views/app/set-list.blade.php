@extends('layouts.app', [
    'title' => isset($title) ? $title : 'Checklists',
    'setViewToggle' => (isset($viewToggle) && $viewToggle) ? view('components.set-view-toggle', ['toggleOn' => 'list'])->render() : null,
])

@section('content')
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
