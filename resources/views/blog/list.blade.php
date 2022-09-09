@extends('layouts.marketing', [
    'title' => 'Blog Articles',
])

@section('content')
    <div>
        <h2>Blog Articles</h2>
        @foreach ($articles as $article)
            <h3><a href="{{ $article['absolute_url'] }}">{{ $article['title'] }}</a></h3>
        @endforeach
    </div>
@endsection
