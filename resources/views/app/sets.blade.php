@extends('layouts.app', [
    'title' => 'Sets',
])

@section('content')
    <x-set-view-toggle toggle-on="group" />

    @forelse ($list as $entry)
    <div>
        <h3>{{ $entry['genre']->name }}</h3>
        
    </div>
    @empty
        <p>No sets</p>
    @endforelse
@endsection
