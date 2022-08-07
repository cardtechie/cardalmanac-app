@extends('layouts.app', [
    'title' => $set->name,
])

@section('content')
    @include('app.set.tabs', ['setId' => $set->id, 'selected' => 'checklist'])

    <set-checklist set-id="{{ $set->id }}"></set-checklist>
@endsection
