<!DOCTYPE html>
<html lang="{{ config('app.locale') }}">
<head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <!-- CSRF Token -->
    <meta name="csrf-token" content="{{ csrf_token() }}">

    @include('layouts.title')

    <!-- Styles -->
    <link href="{{ mix('css/app.css') }}" rel="stylesheet" />

    <!-- Scripts -->
    <script>
        window.Laravel = {!! json_encode([
            'csrfToken' => csrf_token(),
        ]) !!};
    </script>
</head>
<body>
    <div id="app">
        <div class="container">
            <div class="row">
                <div class="col-md-12">
                    <h2>@yield('title')</h2>
                </div>
            </div>

            <div class="row">
                <div class="col-md-9">
                    @yield('content')
                </div>
                <div class="col-md-3">
                    @stack('sidebar')
                </div>
            </div>
        </div>
    </div>
    <footer class="container">
        <div id="app-version" class="text-center">
            {{ config('app.version') }}
        </div>
    </footer>

    <!-- Scripts -->
    <script src="{{ mix('js/app.js') }}"></script>
    <script>
        $(document).on('click', '.panel-buttons span.clickable', function(e) {
            var $this = $(this);
            if(!$this.hasClass('panel-collapsed')) {
                $this.parents('.panel').find('.card-body').slideUp();
                $this.addClass('panel-collapsed');
                $this.removeClass('fa-chevron-down').addClass('fa-chevron-left');
            } else {
                $this.parents('.panel').find('.card-body').slideDown();
                $this.removeClass('panel-collapsed');
                $this.removeClass('fa-chevron-left').addClass('fa-chevron-down');
            }
        })
    </script>
    @stack('scripts')
</body>
</html>
