<header>
    <div class="container flex">
        <h1 class="flex-auto pt-2">
            <a href="{{ config('app.url') }}">{{ config('app.name', 'Laravel') }}</a>
        </h1>
        <nav-menu title="{{ config('app.name', 'Laravel') }}"></nav-menu>
        <nav id="header-nav-menu" class="flex-auto w-1/2 mt-3 lg:block hidden">
            <ul class="float-right">
                <li class="float-right pl-5 text-right uppercase">
                    <a href="{{ route('app.index') }}">App</a>
                </li>
                <li class="float-right pl-5 text-right uppercase">
                    <a href="{{ config('app.url') }}/about">About</a>
                </li>
                <li class="float-right pl-5 text-right uppercase">
                    <a href="{{ config('app.url') }}/blog">Blog</a>
                </li>
            </ul>
        </nav>
    </div>
</header>
