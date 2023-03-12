@extends('layouts.marketing.default', [
    'title' => $title,
])

@section('content')
    <div class="blog-post">
        <h1>{{ $title }}</h1>
        <div>
            By <a href="{{ $author['link'] }}">{{ $author['display_name'] }}</a> on {{ $published_formatted }}
        </div>
        <div class="blog-content">
            {!! $content !!}
        </div>
    </div>
@endsection
