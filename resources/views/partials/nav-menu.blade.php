<header>
    <div class="container flex">
        <h1 class="flex-auto">
            <a href="{{ config('app.url') }}">Card Almanac</a>
        </h1>
        <div class="float-right block lg:hidden">
            <button type="button" class="v-app-bar__nav-icon v-btn v-btn--icon v-btn--round v-size--default">
                <span class="v-btn__content"><i aria-hidden="true" class="v-icon notranslate mdi mdi-menu"></i></span>
            </button>
        </div>
        <nav class="flex-auto w-1/2 mt-3 lg:block hidden">
            <ul class="float-right">
                <li class="float-right pl-5 text-right uppercase">
                    <a href="{{ config('app.url') }}/app">App</a>
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
