<?php

namespace Tests\Feature;

use CardTechie\TradingCardApiSdk\Exceptions\AuthenticationException;
use CardTechie\TradingCardApiSdk\Models\Genre as GenreModel;
use CardTechie\TradingCardApiSdk\Models\Set as SetModel;
use CardTechie\TradingCardApiSdk\Resources\Genre as GenreResource;
use CardTechie\TradingCardApiSdk\Resources\Set as SetResource;
use CardTechie\TradingCardApiSdk\TradingCardApi;
use Illuminate\Pagination\LengthAwarePaginator;
use Mockery;
use Tests\TestCase;

/**
 * Cover for #437's browse:capture-counts command.
 *
 * The command is the instrument that makes the api#2383 draft-status gate
 * falsifiable, so its artifact shape, its degraded path, and its --compare
 * verdict all have to hold -- a capture that silently loses a count would
 * produce exactly the false green the issue warns about.
 */
class BrowseCountCaptureTest extends TestCase
{
    /** @var list<string> */
    private array $tempFiles = [];

    protected function tearDown(): void
    {
        foreach ($this->tempFiles as $file) {
            if (is_file($file)) {
                unlink($file);
            }
        }
        $this->tempFiles = [];

        Mockery::close();

        parent::tearDown();
    }

    private function tempPath(string $name): string
    {
        $path = sys_get_temp_dir() . '/' . $name;
        $this->tempFiles[] = $path;

        return $path;
    }

    /**
     * @param  list<mixed>  $items
     */
    private function paginator(array $items, int $total, int $perPage = 50): LengthAwarePaginator
    {
        return new LengthAwarePaginator($items, $total, $perPage, 1);
    }

    /**
     * Bind an SDK double whose genre and set resources return the given pages.
     *
     * @param  array<string, LengthAwarePaginator|\Throwable>  $setLists  keyed by genre id, plus 'all' for the ungated listing
     */
    private function fakeApi(LengthAwarePaginator|\Throwable $genreList, array $setLists, ?SetModel $set = null): void
    {
        $genreResource = Mockery::mock(GenreResource::class);
        if ($genreList instanceof \Throwable) {
            $genreResource->shouldReceive('list')->andThrow($genreList);
        } else {
            $genreResource->shouldReceive('list')->andReturn($genreList);
        }

        $setResource = Mockery::mock(SetResource::class);
        $setResource->shouldReceive('list')->andReturnUsing(function (array $params = []) use ($setLists) {
            $key = $params['genre'] ?? 'all';
            $result = $setLists[$key] ?? $this->paginator([], 0);

            if ($result instanceof \Throwable) {
                throw $result;
            }

            return $result;
        });

        if ($set !== null) {
            $setResource->shouldReceive('get')->andReturn($set);
        }

        $api = Mockery::mock(TradingCardApi::class);
        $api->shouldReceive('genre')->andReturn($genreResource);
        $api->shouldReceive('set')->andReturn($setResource);

        $this->app->instance(TradingCardApi::class, $api);
    }

    /**
     * @return array<string, mixed>
     */
    private function readArtifact(string $path): array
    {
        $this->assertFileExists($path, 'The command did not write a capture artifact.');

        $decoded = json_decode((string) file_get_contents($path), true);
        $this->assertIsArray($decoded, 'The capture artifact is not valid JSON.');

        return $decoded;
    }

    public function test_a_capture_records_every_browse_count_and_a_traceable_header(): void
    {
        config(['tradingcardapi.url' => 'https://api.example.test']);

        $baseball = new GenreModel(['id' => 'g-baseball', 'name' => 'Baseball']);
        $this->fakeApi(
            $this->paginator([$baseball], 1),
            [
                'g-baseball' => $this->paginator([1, 2, 3], 42, 10),
                'all' => $this->paginator([1, 2], 137),
            ]
        );

        $out = $this->tempPath('browse-counts-shape.json');

        $this->artisan('browse:capture-counts', ['--out' => $out])
            ->assertExitCode(0);

        $artifact = $this->readArtifact($out);

        // Header: two captures must be provably from the same app against the same API.
        $this->assertSame('https://api.example.test', $artifact['api_url']);
        $this->assertSame(getVersion(), $artifact['app_version']);
        $this->assertNotEmpty($artifact['captured_at']);

        $this->assertSame(1, $artifact['counts']['genres.total']);
        $this->assertSame(1, $artifact['counts']['genres.returned']);
        $this->assertSame(42, $artifact['counts']['sets.by_genre.g-baseball.total']);
        $this->assertSame(3, $artifact['counts']['sets.by_genre.g-baseball.returned']);
        $this->assertSame(137, $artifact['counts']['sets.total']);
        $this->assertSame(2, $artifact['counts']['sets.returned']);

        $this->assertSame('Baseball', $artifact['labels']['genre.g-baseball']);
        $this->assertSame([], $artifact['failures']);
    }

    public function test_a_checklist_row_count_is_captured_when_a_set_is_named(): void
    {
        $set = new SetModel(['id' => 's-1', 'name' => '1989 Topps']);
        $set->setRelationships(['checklist' => [1, 2, 3, 4, 5]]);

        $this->fakeApi(
            $this->paginator([], 0),
            ['all' => $this->paginator([], 0)],
            $set
        );

        $out = $this->tempPath('browse-counts-checklist.json');

        $this->artisan('browse:capture-counts', ['--out' => $out, '--set' => 's-1'])
            ->assertExitCode(0);

        $artifact = $this->readArtifact($out);

        $this->assertSame(5, $artifact['counts']['set.s-1.checklist.rows']);
    }

    public function test_a_failed_capture_unit_is_recorded_rather_than_losing_the_whole_capture(): void
    {
        $this->fakeApi(
            new AuthenticationException('Client authentication failed'),
            ['all' => $this->paginator([1], 9)]
        );

        $out = $this->tempPath('browse-counts-degraded.json');

        // Degrade, do not fail: a partial capture is still comparable.
        $this->artisan('browse:capture-counts', ['--out' => $out])
            ->assertExitCode(0);

        $artifact = $this->readArtifact($out);

        $this->assertArrayHasKey('genres', $artifact['failures']);
        $this->assertStringContainsString('Client authentication failed', $artifact['failures']['genres']);

        // The gap is visible rather than silent...
        $this->assertArrayNotHasKey('genres.total', $artifact['counts']);
        // ...and everything that did succeed is still recorded.
        $this->assertSame(9, $artifact['counts']['sets.total']);
    }

    public function test_compare_reports_a_delta_and_exits_non_zero_when_a_count_moves(): void
    {
        $before = $this->tempPath('browse-counts-before.json');
        file_put_contents($before, json_encode([
            'captured_at' => '2026-09-01T00:00:00+00:00',
            'api_url' => 'https://api.example.test',
            'app_version' => getVersion(),
            'counts' => ['sets.total' => 140, 'genres.total' => 3],
            'labels' => [],
            'failures' => [],
        ]));

        config(['tradingcardapi.url' => 'https://api.example.test']);

        $this->fakeApi(
            $this->paginator([], 3),
            ['all' => $this->paginator([], 137)]
        );

        $out = $this->tempPath('browse-counts-after.json');

        $this->artisan('browse:capture-counts', ['--out' => $out, '--compare' => $before])
            ->expectsOutputToContain('-3')
            ->assertExitCode(1);
    }

    public function test_compare_exits_zero_when_nothing_moved(): void
    {
        $before = $this->tempPath('browse-counts-stable-before.json');
        file_put_contents($before, json_encode([
            'captured_at' => '2026-09-01T00:00:00+00:00',
            'api_url' => 'https://api.example.test',
            'app_version' => getVersion(),
            'counts' => [
                'genres.total' => 3,
                'genres.returned' => 0,
                'sets.total' => 137,
                'sets.returned' => 0,
            ],
            'labels' => [],
            'failures' => [],
        ]));

        config(['tradingcardapi.url' => 'https://api.example.test']);

        $this->fakeApi(
            $this->paginator([], 3),
            ['all' => $this->paginator([], 137)]
        );

        $out = $this->tempPath('browse-counts-stable-after.json');

        $this->artisan('browse:capture-counts', ['--out' => $out, '--compare' => $before])
            ->assertExitCode(0);
    }

    public function test_compare_against_a_file_that_is_not_an_artifact_fails_loudly(): void
    {
        $notAnArtifact = $this->tempPath('browse-counts-garbage.json');
        file_put_contents($notAnArtifact, '{"hello":"world"}');

        $this->fakeApi(
            $this->paginator([], 0),
            ['all' => $this->paginator([], 0)]
        );

        $out = $this->tempPath('browse-counts-garbage-after.json');

        // A file that parses but carries no counts must not read as "nothing moved".
        $this->artisan('browse:capture-counts', ['--out' => $out, '--compare' => $notAnArtifact])
            ->assertExitCode(1);
    }

    public function test_compare_warns_when_the_two_captures_came_from_different_apis(): void
    {
        $before = $this->tempPath('browse-counts-other-api.json');
        file_put_contents($before, json_encode([
            'captured_at' => '2026-09-01T00:00:00+00:00',
            'api_url' => 'https://staging.example.test',
            'app_version' => getVersion(),
            'counts' => ['genres.total' => 3, 'genres.returned' => 0, 'sets.total' => 137, 'sets.returned' => 0],
            'labels' => [],
            'failures' => [],
        ]));

        config(['tradingcardapi.url' => 'https://api.example.test']);

        $this->fakeApi(
            $this->paginator([], 3),
            ['all' => $this->paginator([], 137)]
        );

        $out = $this->tempPath('browse-counts-other-api-after.json');

        // Identical numbers across two different APIs are a coincidence, not a
        // gate measurement -- the zero delta must not read as a silent pass.
        $this->artisan('browse:capture-counts', ['--out' => $out, '--compare' => $before])
            ->expectsOutputToContain('DIFFERENT API URLs')
            ->assertExitCode(0);
    }

    public function test_compare_against_a_count_less_baseline_fails_loudly(): void
    {
        $before = $this->tempPath('browse-counts-empty-baseline.json');
        file_put_contents($before, json_encode([
            'captured_at' => '2026-09-01T00:00:00+00:00',
            'api_url' => 'https://api.example.test',
            'app_version' => getVersion(),
            'counts' => [],
            'labels' => [],
            'failures' => ['genres' => 'AuthenticationException: nope'],
        ]));

        config(['tradingcardapi.url' => 'https://api.example.test']);

        $this->fakeApi(
            $this->paginator([], 3),
            ['all' => $this->paginator([], 137)]
        );

        $out = $this->tempPath('browse-counts-empty-baseline-after.json');

        // A baseline with no counts diffs to zero keys and zero changes. Reading
        // that as "nothing moved" is the false green #437 exists to prevent.
        $this->artisan('browse:capture-counts', ['--out' => $out, '--compare' => $before])
            ->assertExitCode(1);
    }

    public function test_compare_fails_when_the_fresh_capture_recorded_no_counts(): void
    {
        $before = $this->tempPath('browse-counts-live-baseline.json');
        file_put_contents($before, json_encode([
            'captured_at' => '2026-09-01T00:00:00+00:00',
            'api_url' => 'https://api.example.test',
            'app_version' => getVersion(),
            'counts' => ['genres.total' => 3, 'sets.total' => 137],
            'labels' => [],
            'failures' => [],
        ]));

        config(['tradingcardapi.url' => 'https://api.example.test']);

        // Every capture unit fails -- e.g. an SDK or API change this app has not
        // caught up with. The artifact carries no counts at all.
        $this->fakeApi(
            new AuthenticationException('Client authentication failed'),
            ['all' => new AuthenticationException('Client authentication failed')]
        );

        $out = $this->tempPath('browse-counts-no-counts-after.json');

        $this->artisan('browse:capture-counts', ['--out' => $out, '--compare' => $before])
            ->assertExitCode(1);
    }

    public function test_a_capture_that_cannot_be_written_fails_rather_than_reporting_success(): void
    {
        // A regular file where the artifact's directory should be: mkdir cannot
        // create it, so the artifact can never land on disk.
        $blocker = $this->tempPath('browse-counts-blocker');
        file_put_contents($blocker, 'not a directory');

        $this->fakeApi(
            $this->paginator([], 0),
            ['all' => $this->paginator([], 0)]
        );

        // The artifact is the whole point of the command -- an in-memory capture
        // that was printed but never written must not exit zero.
        $this->artisan('browse:capture-counts', ['--out' => $blocker . '/capture.json'])
            ->assertExitCode(1);
    }

    public function test_compare_against_a_missing_artifact_fails_loudly(): void
    {
        $this->fakeApi(
            $this->paginator([], 0),
            ['all' => $this->paginator([], 0)]
        );

        $out = $this->tempPath('browse-counts-no-baseline.json');

        $this->artisan('browse:capture-counts', [
            '--out' => $out,
            '--compare' => sys_get_temp_dir() . '/browse-counts-does-not-exist.json',
        ])->assertExitCode(1);
    }
}
