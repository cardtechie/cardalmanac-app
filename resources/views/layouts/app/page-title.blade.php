@if (!isset($showPageTitle) || $showPageTitle !== false)
    <div class="container max-w-6xl mt-6 flex items-center justify-between">
        <h2 class="mb-0">{{ $title }}</h2>
        @isset($setViewToggle)
            <div class="ml-4">{!! $setViewToggle !!}</div>
        @endisset
    </div>
@endif
