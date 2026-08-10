@extends('layouts.app', [
    'title' => 'Temporarily Unavailable',
    'overrideBreadcrumbs' => true,
])

{{-- Breadcrumbs for set routes resolve the set, which is exactly what is failing. --}}
@section('breadcrumbs')
@endsection

@section('content')
<div class="mb-6">
    <p>We can't reach the card data service right now, so checklists aren't available.</p>
    <p>This is a problem on our end, not with your connection. Please try again in a few minutes.</p>
    <p class="pt-2">
        <a href="{{ route('home') }}">Return to the homepage</a>
    </p>
</div>
@endsection
