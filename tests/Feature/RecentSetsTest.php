<?php

namespace Tests\Feature;

use CardTechie\TradingCardApiSdk\Exceptions\AuthenticationException;
use CardTechie\TradingCardApiSdk\Resources\Set as SetResource;
use CardTechie\TradingCardApiSdk\TradingCardApi;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\Cache;
use Mockery;
use Tests\TestCase;

/**
 * Recently added sets page and Atom feed (#526).
 */
class RecentSetsTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        Cache::flush();
    }

    protected function tearDown(): void
    {
        Mockery::close();

        parent::tearDown();
    }

    private function fakeSet(string $id, string $name, int $year, int $cards, string $createdAt): object
    {
        $yearObject = (object) ['year' => $year, 'name' => (string) $year];

        return new class($id, $name, $yearObject, $cards, $createdAt)
        {
            public function __construct(
                public string $id,
                public string $name,
                private object $yearObject,
                public int $card_count,
                public string $created_at
            ) {
            }

            public function year(): object
            {
                return $this->yearObject;
            }
        };
    }

    /**
     * @param  array<int, object>  $sets
     */
    private function fakeApiReturning(array $sets, int $times = 1): void
    {
        $resource = Mockery::mock(SetResource::class);
        $resource->shouldReceive('list')->times($times)->andReturn(new LengthAwarePaginator($sets, count($sets), 25));

        $api = Mockery::mock(TradingCardApi::class);
        $api->shouldReceive('set')->andReturn($resource);

        $this->app->instance(TradingCardApi::class, $api);
    }

    private function fakeApiThrowing(\Throwable $e): void
    {
        $resource = Mockery::mock(SetResource::class);
        $resource->shouldReceive('list')->andThrow($e);

        $api = Mockery::mock(TradingCardApi::class);
        $api->shouldReceive('set')->andReturn($resource);

        $this->app->instance(TradingCardApi::class, $api);
    }

    private function twoSets(): array
    {
        return [
            $this->fakeSet('id-new', 'Newest Set', 2026, 300, '2026-10-10T12:00:00+00:00'),
            $this->fakeSet('id-old', 'Older Set', 2025, 150, '2026-09-01T08:30:00+00:00'),
        ];
    }

    public function test_page_lists_sets_newest_first_with_links_and_feed_autodiscovery(): void
    {
        $this->fakeApiReturning($this->twoSets());

        $response = $this->get('/app/recent-sets');

        $response->assertStatus(200);
        $response->assertSeeInOrder(['Newest Set', 'Older Set']);
        $response->assertSee('/app/sets/id-new/newest-set', false);
        $response->assertSee('300 cards');
        $response->assertSee('rel="alternate" type="application/atom+xml"', false);
    }

    public function test_zero_card_counts_are_rendered_on_the_page_and_in_the_feed(): void
    {
        $this->fakeApiReturning([$this->fakeSet('id-empty', 'Empty Set', 2026, 0, '2026-10-11T12:00:00+00:00')]);

        $this->get('/app/recent-sets')->assertStatus(200)->assertSee('0 cards');
        $this->get('/app/recent-sets.atom')->assertStatus(200)->assertSee('(0 cards)', false);
    }

    public function test_empty_list_shows_the_empty_state(): void
    {
        $this->fakeApiReturning([]);

        $this->get('/app/recent-sets')
            ->assertStatus(200)
            ->assertSee('No checklists have been added yet.');
    }

    public function test_feed_is_valid_atom_with_one_stable_entry_per_set(): void
    {
        $this->fakeApiReturning($this->twoSets());

        $response = $this->get('/app/recent-sets.atom');

        $response->assertStatus(200);
        $this->assertStringContainsString('application/atom+xml', $response->headers->get('Content-Type'));

        $xml = simplexml_load_string($response->getContent());
        $this->assertNotFalse($xml);
        $xml->registerXPathNamespace('a', 'http://www.w3.org/2005/Atom');
        $this->assertCount(2, $xml->xpath('//a:entry'));
        $this->assertSame('urn:cardalmanac:set:id-new', (string) $xml->xpath('//a:entry/a:id')[0]);
        $this->assertStringContainsString('/app/sets/id-new/newest-set', (string) $xml->xpath('//a:entry/a:link/@href')[0]);
        $this->assertSame('2026-10-10T12:00:00+00:00', (string) $xml->updated);
    }

    public function test_api_failure_degrades_the_page_and_returns_503_for_the_feed(): void
    {
        $this->fakeApiThrowing(new AuthenticationException('Client authentication failed'));

        $this->get('/app/recent-sets')->assertStatus(503)->assertSee('card data service');
        $this->get('/app/recent-sets.atom')->assertStatus(503);
    }

    public function test_a_second_request_is_served_from_cache(): void
    {
        $this->fakeApiReturning($this->twoSets(), 1);

        $this->get('/app/recent-sets')->assertStatus(200);
        $this->get('/app/recent-sets.atom')->assertStatus(200);
    }
}
