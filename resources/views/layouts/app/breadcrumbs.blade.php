@if (isset($overrideBreadcrumbs) && $overrideBreadcrumbs)
    @yield('breadcrumbs')
@else
    {{ Breadcrumbs::render() }}
@endif
