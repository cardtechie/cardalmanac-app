@extends('layouts.app', [
    'title' => $set->name,
])

@section('content')
    @include('app.set.tabs', ['setId' => $set->id, 'selected' => 'subsets'])
    <h1>Subsets</h1>
@endsection
