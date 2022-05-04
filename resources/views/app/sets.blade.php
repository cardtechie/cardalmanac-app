@extends('layouts.app', [
    'title' => 'Sets',
])

@section('content')
    <div class="home main text-center container max-w-sm max-w-md max-w-lg mx-auto mt-32">
        <p class="font-medium pb-6 uppercase">Sets</p>
    @forelse ($sets as $set)
        @if ($loop->first)
            <ul>
        @endif
        <li>{{ $set->name }}</li>
        @if ($loop->last)
            </ul>
        @endif
    @empty
        <p>No sets</p>
    @endforelse
    </div>
@endsection
