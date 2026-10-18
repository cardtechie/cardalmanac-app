<feed xmlns="http://www.w3.org/2005/Atom">
    <id>{{ route('app.recent-sets.feed') }}</id>
    <title>Card Almanac: recently added checklists</title>
    <updated>{{ $updated }}</updated>
    <link rel="self" type="application/atom+xml" href="{{ route('app.recent-sets.feed') }}" />
    <link rel="alternate" type="text/html" href="{{ route('app.recent-sets') }}" />
@foreach ($sets as $set)
    <entry>
        <id>urn:cardalmanac:set:{{ $set['id'] }}</id>
        <title>{{ $set['name'] }}</title>
        <link rel="alternate" type="text/html" href="{{ $set['url'] }}" />
        <updated>{{ $set['created_at'] ?? $updated }}</updated>
        <summary>{{ trim(($set['year'] ? $set['year'].' ' : '').$set['name']) }}@if ($set['card_count']) ({{ number_format($set['card_count']) }} cards)@endif</summary>
    </entry>
@endforeach
</feed>
