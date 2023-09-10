@extends('layouts.app', [
    'title' => $set->name,
    'overrideBreadcrumbs' => true,
])

@section('breadcrumbs')
    Breadcrumbs
@endsection

@section('content')
    @include('app.set.tabs', ['setId' => $set->id, 'selected' => 'details'])
    <div class="tab-content" id="tabs-tabContent">
        <div class="tab-pane fade show active" id="tabs-details" role="tabpanel" aria-labelledby="tabs-details-tab">
            <dl>
                <div class="even:bg-gray-50 odd:bg-white px-4 py-3 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt class="text-sm font-medium text-gray-500">Total Cards</dt>
                    <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">{{ $set->card_count }}</dd>
                </div>

            @if ($set->manufacturer())
                <div class="even:bg-gray-50 odd:bg-white px-4 py-3 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt class="text-sm font-medium text-gray-500">Manufacturer</dt>
                    <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">{{ $set->manufacturer()->name }}</dd>
                </div>
            @endif

            @if ($set->genre())
                <div class="even:bg-gray-50 odd:bg-white px-4 py-3 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt class="text-sm font-medium text-gray-500">Genre</dt>
                    <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">{{ $set->genre()->name }}</dd>
                </div>
            @endif

            @if ($set->year())
                <div class="even:bg-gray-50 odd:bg-white px-4 py-3 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt class="text-sm font-medium text-gray-500">Year</dt>
                    <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">{{ $set->year()->name }}</dd>
                </div>
            @endif
            </dl>
        </div>
        <div class="tab-pane fade" id="tabs-checklist" role="tabpanel" aria-labelledby="tabs-checklist-tab">
            Checklist
        </div>
        <div class="tab-pane fade" id="tabs-subsets" role="tabpanel" aria-labelledby="tabs-subsets-tab">
            Subsets
        </div>
    </div>
@endsection
