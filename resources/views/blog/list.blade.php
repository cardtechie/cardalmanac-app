@extends('layouts.marketing', [
    'title' => 'Home',
])

@section('content')
    <div>
        <h2>Articles</h2>
        @foreach ($articles as $article)
            <h3><a href="{{ $article['absolute_url'] }}">{{ $article['title'] }}</a></h3>
        @endforeach
    </div>
@endsection
