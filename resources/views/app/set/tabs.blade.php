<ul class="nav nav-tabs flex flex-col md:flex-row flex-wrap list-none border-b-0 pl-0 mb-4" id="tabs-tab" role="tablist">
    <li class="nav-item" role="presentation">
        <a href="{{ config('app.url') }}/app/sets/{{ $setId }}"
           class="@if ($selected === 'details') active @endif nav-link block font-medium text-xs leading-tight uppercase border-x-0 border-t-0 border-b-2 border-transparent px-6 py-3 my-2 hover:border-transparent hover:bg-gray-100 focus:border-transparent"
           id="tabs-details-tab"
           role="tab"
           aria-controls="tabs-details"
           aria-selected="@if ($selected === 'details') true @else false @endif"
        >Details</a>
    </li>
    <li class="nav-item" role="presentation">
        <a href="{{ config('app.url') }}/app/sets/{{ $setId }}/checklist"
           class="@if ($selected === 'checklist') active @endif nav-link block font-medium text-xs leading-tight uppercase border-x-0 border-t-0 border-b-2 border-transparent px-6 py-3 my-2 hover:border-transparent hover:bg-gray-100 focus:border-transparent"
           id="tabs-checklist-tab"
           role="tab"
           aria-controls="tabs-checklist"
           aria-selected="@if ($selected === 'checklist') true @else false @endif"
        >Checklist</a>
    </li>
    <li class="nav-item" role="presentation">
        <a href="{{ config('app.url') }}/app/sets/{{ $setId }}/subsets"
           class="@if ($selected === 'subsets') active @endif nav-link block font-medium text-xs leading-tight uppercase border-x-0 border-t-0 border-b-2 border-transparent px-6 py-3 my-2 hover:border-transparent hover:bg-gray-100 focus:border-transparent"
           id="tabs-subsets-tab"
           role="tab"
           aria-controls="tabs-subsets"
           aria-selected="@if ($selected === 'subsets') true @else false @endif"
        >Subsets</a>
    </li>
</ul>
