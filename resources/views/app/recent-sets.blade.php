@extends('layouts.app', [
    'title' => isset($title) ? $title : 'Recently Added Checklists',
])

@push('head')
    <link rel="alternate" type="application/atom+xml" title="Recently added checklists" href="{{ route('app.recent-sets.feed') }}" />
@endpush

@section('content')
    <div class="mt-8">
    @forelse ($sets as $set)
        @if ($loop->first)
            <ul>
        @endif
            <li>
                <a href="{{ $set['url'] }}">{{ $set['name'] }}</a>
                @if ($set['year'])
                    ({{ $set['year'] }})
                @endif
                @if (! is_null($set['card_count']))
                    &middot; {{ number_format($set['card_count']) }} cards
                @endif
            </li>
        @if ($loop->last)
            </ul>
        @endif
    @empty
        <p>No checklists have been added yet.</p>
    @endforelse
        <p class="mt-6 text-sm"><a href="{{ route('app.recent-sets.feed') }}">Subscribe via Atom feed</a></p>
    </div>
@endsection
