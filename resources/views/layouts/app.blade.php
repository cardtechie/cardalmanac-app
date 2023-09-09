<!DOCTYPE html>
<html lang="{{ config('app.locale') }}">
<head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <!-- CSRF Token -->
    <meta name="csrf-token" content="{{ csrf_token() }}">

    @include('partials.head-title')

    <!-- Styles -->
    <link href="{{ mix('css/app.css') }}" rel="stylesheet" />
    <link href="https://fonts.googleapis.com/css?family=Roboto:100,300,400,500,700,900" rel="stylesheet" />
    <link href="https://cdn.jsdelivr.net/npm/@mdi/font@6.x/css/materialdesignicons.min.css" rel="stylesheet" />

    <!-- Scripts -->
    <script>
        window.Laravel = {!! json_encode([
            'csrfToken' => csrf_token(),
        ]) !!};
    </script>
    @include('partials.analytics')
    @include('partials.head-gtm')
</head>
<body>
    @include('partials.body-gtm')
    <div id="app" class="flex flex-col min-h-screen">
        @include('partials.nav-menu')
        {{ Breadcrumbs::render() }}
        @include('layouts.app.page-title')

        <div class="container max-w-6xl">
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

        @include('partials.footer')
    </div>

    <!-- Scripts -->
    <script src="{{ mix('js/app.js') }}"></script>
    @stack('scripts')
</body>
</html>
