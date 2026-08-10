<?php

namespace Tests\Feature;

use CardTechie\TradingCardApiSdk\Exceptions\AuthenticationException;
use CardTechie\TradingCardApiSdk\Exceptions\ResourceNotFoundException;
use CardTechie\TradingCardApiSdk\Resources\Genre as GenreResource;
use CardTechie\TradingCardApiSdk\Resources\Set as SetResource;
use CardTechie\TradingCardApiSdk\TradingCardApi;
use Illuminate\Support\Facades\Log;
use Mockery;
use Tests\TestCase;

/**
 * Regression tests for #397: an API failure used to render a blank 500 on
 * every content page, because nothing caught the SDK's exceptions.
 */
class ApiFailureHandlingTest extends TestCase
{
    protected function tearDown(): void
    {
        Mockery::close();

        parent::tearDown();
    }

    /**
     * Swap the SDK out for a double whose given resource throws.
     */
    private function fakeApiThrowing(string $resourceMethod, string $resourceClass, \Throwable $e): void
    {
        $resource = Mockery::mock($resourceClass);
        $resource->shouldReceive('list', 'get')->andThrow($e);

        $api = Mockery::mock(TradingCardApi::class);
        $api->shouldReceive($resourceMethod)->andReturn($resource);

        $this->app->instance(TradingCardApi::class, $api);
    }

    public function test_auth_failure_renders_a_degraded_page_instead_of_a_blank_500(): void
    {
        $this->fakeApiThrowing(
            'genre',
            GenreResource::class,
            new AuthenticationException('Client authentication failed')
        );

        $response = $this->get('/app/sets');

        $response->assertStatus(503);
        $response->assertSee('card data service');
        $response->assertSee('Return to the homepage');
    }

    public function test_set_list_also_degrades_rather_than_failing_hard(): void
    {
        $this->fakeApiThrowing(
            'set',
            SetResource::class,
            new AuthenticationException('Client authentication failed')
        );

        $this->get('/app/sets/list')->assertStatus(503);
    }

    public function test_a_missing_set_is_a_404_not_a_server_error(): void
    {
        $this->fakeApiThrowing(
            'set',
            SetResource::class,
            new ResourceNotFoundException('Set not found')
        );

        $this->get('/app/sets/00000000-0000-0000-0000-000000000000/bogus')
            ->assertStatus(404);
    }

    public function test_a_missing_set_is_logged_at_info_not_error(): void
    {
        $this->fakeApiThrowing(
            'set',
            SetResource::class,
            new ResourceNotFoundException('Set not found')
        );

        Log::spy();

        $this->get('/app/sets/00000000-0000-0000-0000-000000000000/bogus')
            ->assertStatus(404);

        // Crawlers hitting bogus ids must not drown out failures worth alerting on.
        Log::shouldNotHaveReceived('error');
        Log::shouldHaveReceived('info')
            ->withArgs(fn (string $message) => $message === 'Trading Card API resource not found');
    }

    public function test_a_real_api_failure_is_still_reported_as_an_error(): void
    {
        $this->fakeApiThrowing(
            'genre',
            GenreResource::class,
            new AuthenticationException('Client authentication failed')
        );

        Log::spy();

        $this->get('/app/sets')->assertStatus(503);

        Log::shouldHaveReceived('error');
    }

    public function test_json_clients_get_a_json_error_not_html(): void
    {
        $this->fakeApiThrowing(
            'genre',
            GenreResource::class,
            new AuthenticationException('Client authentication failed')
        );

        $this->getJson('/app/sets')
            ->assertStatus(503)
            ->assertJson(['message' => 'The card data service is temporarily unavailable.']);
    }

    public function test_pages_that_do_not_use_the_api_are_unaffected(): void
    {
        $this->fakeApiThrowing(
            'genre',
            GenreResource::class,
            new AuthenticationException('Client authentication failed')
        );

        $this->get('/')->assertStatus(200);
    }
}
