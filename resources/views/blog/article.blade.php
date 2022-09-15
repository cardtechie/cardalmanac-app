@extends('layouts.marketing', [
    'title' => $title,
])

@section('content')
    <div class="blog-post">
        <h1>{{ $title }}</h1>
        <div>
            {{ $published_formatted }}
        </div>
        <div class="blog-content">
            {!! $content !!}
        </div>
    </div>
@endsection
