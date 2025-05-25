@extends('layouts.app', [
    'title' => isset($title) ? $title : 'Checklists',
])

@section('content')
<x-set-view-toggle toggle-on="group" />

<div class="grid md:grid-cols-3">
    @forelse ($list as $entry)
    <div class="mb-6">
        <h3 class="mb-2">{{ $entry['genre']->name }} Card Checklists</h3>
        <ul>
        @forelse ($entry['sets']->toArray()['data'] as $set)
            <li>
                <a href="{{ route('app.set', ['id' => $set->id, 'name' => str()->slug($set->name)]) }}">{{ $set->name }}</a>
            </li>
        @empty
            <li>No checklists for this genre have been published.</li>
        @endforelse
        </ul>

        <div class="pt-2 text-sm">
            <a href="{{ route('app.set.genre', ['genre' => $entry['genre']->id, 'name' => str()->slug($entry['genre']->name)]) }}">
                Browse {{ $entry['genre']->name }} card checklists &raquo;
            </a>
        </div>
    </div>
    @empty
        <p>No checklists have been published.</p>
    @endforelse
</div>
@endsection
