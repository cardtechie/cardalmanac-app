@extends('layouts.app', [
    'title' => $set->name,
])

@section('content')
    @include('app.set.tabs', ['setId' => $set->id, 'selected' => 'checklist'])
    <h1>Checklist</h1>
    <set-checklist></set-checklist>
@endsection
