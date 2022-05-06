<!DOCTYPE html>
<html lang="{{ config('app.locale') }}">
<head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <!-- CSRF Token -->
    <meta name="csrf-token" content="{{ csrf_token() }}">

    @include('partials.title')

    <!-- Styles -->
    <link href="{{ mix('css/app.css') }}" rel="stylesheet" />

    <!-- Scripts -->
@if (app()->environment('production'))
    @include('partials.analytics')
@endif
    <script>
        window.Laravel = {!! json_encode([
            'csrfToken' => csrf_token(),
        ]) !!};
    </script>
</head>
<body>
    <div id="app" class="container">
        @include('layouts.app.header')

        @if (isset($showPageTitle) && $showPageTitle === true)
        <div class="row">
            <div class="col-md-12">
                <h2>{{ $title }}</h2>
            </div>
        </div>
        @endif

        <div class="row">
            <div
                {!! (isset($showSidebar) && $showSidebar === true) ? "class='col-md-9'" : "class='col-md-12'" !!}
            >
                @yield('content')
            </div>
            @isset($showSidebar)
                @if ($showSidebar)
            <div class="col-md-3">
                @stack('sidebar')
            </div>
                @endif
            @endisset
        </div>
    </div>
    <footer class="container">
        <div id="app-version" class="text-center">
            {{ config('app.version') }}
        </div>
    </footer>

    <!-- Scripts -->
    <script src="{{ mix('js/app.js') }}"></script>
    @stack('scripts')
</body>
</html>
