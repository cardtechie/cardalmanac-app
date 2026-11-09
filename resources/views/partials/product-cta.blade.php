{{--
    Contextual product call-to-action.

    Renders every enabled entry in config('services.products.ctas'). The list
    shape is the extension point: adding another product CTA is a config change
    and requires no edit here. Renders nothing when no entry is enabled.
--}}
@php
    $productCtas = collect(config('services.products.ctas', []))
        ->filter(fn ($cta) => ! empty($cta['enabled']) && ! empty($cta['url']));
@endphp

@if ($productCtas->isNotEmpty())
    <div class="mt-6 space-y-3">
        @foreach ($productCtas as $cta)
            <div class="border border-gray-200 bg-gray-50 rounded-md px-4 py-3 sm:px-6">
                <p class="text-sm font-medium text-gray-900">{{ $cta['heading'] ?? '' }}</p>
                @if (! empty($cta['body']))
                    <p class="mt-1 text-sm text-gray-500">{{ $cta['body'] }}</p>
                @endif
                <a
                    href="{{ $cta['url'] }}"
                    rel="noopener"
                    class="mt-2 inline-block text-sm font-medium text-blue-600 hover:text-blue-800 hover:underline"
                >{{ $cta['link_text'] ?? 'Learn more' }}</a>
            </div>
        @endforeach
    </div>
@endif
