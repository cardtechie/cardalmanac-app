@extends('layouts.app', [
    'title' => $set->name,
])

@section('content')
    <ul class="nav nav-tabs flex flex-col md:flex-row flex-wrap list-none border-b-0 pl-0 mb-4" id="tabs-tab" role="tablist">
        <li class="nav-item" role="presentation">
            <a href="#tabs-details"
               class="nav-link block font-medium text-xs leading-tight uppercase border-x-0 border-t-0 border-b-2 border-transparent px-6 py-3 my-2 hover:border-transparent hover:bg-gray-100 focus:border-transparent active"
               id="tabs-details-tab"
               data-bs-toggle="pill"
               data-bs-target="#tabs-details"
               role="tab"
               aria-controls="tabs-details"
               aria-selected="true"
            >Details</a>
        </li>
        <li class="nav-item" role="presentation">
            <a href="#tabs-checklist"
               class="nav-link block font-medium text-xs leading-tight uppercase border-x-0 border-t-0 border-b-2 border-transparent px-6 py-3 my-2 hover:border-transparent hover:bg-gray-100 focus:border-transparent"
               id="tabs-checklist-tab"
               data-bs-toggle="pill"
               data-bs-target="#tabs-checklist"
               role="tab"
               aria-controls="tabs-checklist"
               aria-selected="false"
            >Checklist</a>
        </li>
        <li class="nav-item" role="presentation">
            <a href="#tabs-subsets"
               class="nav-link block font-medium text-xs leading-tight uppercase border-x-0 border-t-0 border-b-2 border-transparent px-6 py-3 my-2 hover:border-transparent hover:bg-gray-100 focus:border-transparent"
               id="tabs-subsets-tab"
               data-bs-toggle="pill"
               data-bs-target="#tabs-subsets"
               role="tab"
               aria-controls="tabs-subsets"
               aria-selected="false"
            >Subsets</a>
        </li>
    </ul>
    <div class="tab-content" id="tabs-tabContent">
        <div class="tab-pane fade show active" id="tabs-details" role="tabpanel" aria-labelledby="tabs-details-tab">
            <dl>
                <div class="bg-gray-50 px-4 py-3 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt class="text-sm font-medium text-gray-500">Total Cards</dt>
                    <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">{{ $set->card_count }}</dd>
                </div>

                <div class="bg-white px-4 py-3 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt class="text-sm font-medium text-gray-500">Manufacturer</dt>
                    <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">{{ $set->manufacturer()->name }}</dd>
                </div>

                <div class="bg-gray-50 px-4 py-3 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt class="text-sm font-medium text-gray-500">Genre</dt>
                    <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">{{ $set->genre()->name }}</dd>
                </div>

                <div class="bg-white px-4 py-3 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt class="text-sm font-medium text-gray-500">Year</dt>
                    <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">{{ $set->year()->name }}</dd>
                </div>
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
