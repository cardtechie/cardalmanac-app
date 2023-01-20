<header>
    <div class="container flex">
        <h1 class="flex-auto">
            <a href="{{ config('app.url') }}">Card Almanac</a>
        </h1>
        <div class="float-right block lg:hidden">
            <button id="header-nav-button" type="button" class="v-app-bar__nav-icon v-btn v-btn--icon v-btn--round v-size--default" data-bs-toggle="offcanvas" data-bs-target="#offcanvasRight" aria-controls="offcanvasRight">
                <span><i aria-hidden="true" class="v-icon notranslate mdi mdi-menu"></i></span>
            </button>
        </div>
        <nav id="header-nav-menu" class="flex-auto w-1/2 mt-3 lg:block hidden">
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
    <div class="offcanvas offcanvas-end fixed bottom-0 flex flex-col max-w-full bg-white invisible bg-clip-padding shadow-sm outline-none transition duration-300 ease-in-out text-gray-700 top-0 right-0 border-none w-96" tabindex="-1" id="offcanvasRight" aria-labelledby="offcanvasRightLabel">
        <div class="offcanvas-header flex items-center justify-between p-4">
            <h5 class="offcanvas-title mb-0 leading-normal font-semibold" id="offcanvasRightLabel">Offcanvas right</h5>
            <button type="button" class="btn-close box-content w-4 h-4 p-2 -my-5 -mr-2 text-black border-none rounded-none opacity-50 focus:shadow-none focus:outline-none focus:opacity-100 hover:text-black hover:opacity-75 hover:no-underline" data-bs-dismiss="offcanvas" aria-label="Close"></button>
        </div>
        <div class="offcanvas-body flex-grow p-4 overflow-y-auto">
            ...
        </div>
    </div>
</header>
