@extends('layouts.marketing.home', [
    'title' => 'Home',
])

@section('content')
    @include('layouts.marketing.home.app-teaser-component')
    @include('layouts.marketing.home.blogpost-component')
    {{--  @include('layouts.marketing.home.mailing-list-component') --}}
@endsection
