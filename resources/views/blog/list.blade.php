@extends('layouts.marketing.default', [
    'title' => 'Blog Articles',
])

@section('content')
    <div>
        <h2>Blog Articles</h2>
        @foreach ($articles as $article)
            <h3><a href="{{ $article['absolute_url'] }}">{{ $article['title'] }}</a></h3>
            <div>{{ $article['published_formatted'] }}</div>
        @endforeach
    </div>
@endsection
