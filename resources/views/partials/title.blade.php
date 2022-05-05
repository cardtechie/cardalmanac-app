<title>
    @isset($title)
        {{ $title }} |
    @endisset
    {{ config('app.name', 'Laravel') }}
</title>
