@extends('layouts.marketing', [
    'title' => 'Blog Article',
])

@section('content')
    <div>
        {!! $content !!}
    </div>
@endsection
