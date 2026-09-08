<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Pagination\LengthAwarePaginator;
use Throwable;

/**
 * Capture every visitor-facing count this app surfaces, as a comparable artifact.
 *
 * This exists for cardtechie/cardalmanac-app#437: the Trading Card API gained a
 * draft-status gate (cardtechie/tradingcardapi-api#2383) that is silent by design
 * -- a caller on a customer-grade token gets no error, only fewer rows. A silent
 * gate cannot be verified by reasoning about it, so this command records the real
 * numbers a real request returns, and `--compare` diffs two such records.
 *
 * The command draws no conclusions. It reports deltas; a human decides whether the
 * deltas are explained by draft-only entities disappearing.
 */
class CaptureBrowseCounts extends Command
{
    /**
     * @var string
     */
    protected $signature = 'browse:capture-counts
        {--out= : Where to write the capture artifact (default: storage/app/browse-counts-<timestamp>.json)}
        {--set= : A set id whose checklist row count should also be captured}
        {--compare= : Path to an earlier artifact; takes a fresh capture and diffs it against that one}';

    /**
     * @var string
     */
    protected $description = 'Capture the browse counts this app surfaces, and optionally diff them against an earlier capture';

    public function handle(): int
    {
        $artifact = $this->capture();

        $outPath = $this->resolveOutPath($artifact['captured_at']);
        $this->writeArtifact($outPath, $artifact);
        $this->info(sprintf('Capture written to %s', $outPath));

        $this->renderArtifact($artifact);

        $comparePath = (string) ($this->option('compare') ?? '');
        if ($comparePath === '') {
            return self::SUCCESS;
        }

        return $this->compare($comparePath, $artifact);
    }

    /**
     * Take a live capture through the app's own configured SDK client, so the
     * numbers are the ones this app's token actually sees.
     *
     * @return array<string, mixed>
     */
    private function capture(): array
    {
        /** @var array<string, int> $counts */
        $counts = [];
        /** @var array<string, string> $failures */
        $failures = [];
        /** @var array<string, string> $labels */
        $labels = [];

        // Mirrors SetController::index -- the genre rail on /app/sets.
        $genres = $this->attempt('genres', $failures, fn () => tradingcardapi()->genre()->list());
        if ($genres instanceof LengthAwarePaginator) {
            $counts['genres.total'] = $genres->total();
            $counts['genres.returned'] = $genres->count();

            foreach ($genres as $genre) {
                $genreId = (string) $genre->id;
                $labels['genre.' . $genreId] = (string) $genre->name;

                $key = 'sets.by_genre.' . $genreId;
                $sets = $this->attempt($key, $failures, fn () => tradingcardapi()->set()->list([
                    'genre' => $genreId,
                    'limit' => 10,
                    'order_by' => 'created_at',
                ]));

                if ($sets instanceof LengthAwarePaginator) {
                    $counts[$key . '.total'] = $sets->total();
                    $counts[$key . '.returned'] = $sets->count();
                }
            }
        }

        // Mirrors SetController::list -- the full A-Z listing on /app/sets/list.
        $allSets = $this->attempt('sets', $failures, fn () => tradingcardapi()->set()->list([
            'include' => 'genre',
        ]));
        if ($allSets instanceof LengthAwarePaginator) {
            $counts['sets.total'] = $allSets->total();
            $counts['sets.returned'] = $allSets->count();
        }

        // Mirrors SetController::checklist -- the rows a visitor sees on one set.
        $setId = (string) ($this->option('set') ?? '');
        if ($setId !== '') {
            $key = 'set.' . $setId . '.checklist.rows';
            $set = $this->attempt($key, $failures, fn () => tradingcardapi()->set()->get($setId, [
                'include' => 'checklist',
            ]));

            if ($set !== null) {
                $counts[$key] = count($set->checklist());
            }
        }

        ksort($counts);
        ksort($labels);
        ksort($failures);

        return [
            'captured_at' => now()->utc()->toIso8601String(),
            'api_url' => (string) config('tradingcardapi.url'),
            'app_version' => getVersion(),
            'counts' => $counts,
            'labels' => $labels,
            'failures' => $failures,
        ];
    }

    /**
     * Run one capture unit, recording rather than raising on failure.
     *
     * A partially failed capture is still comparable, and its gaps are visible in
     * the artifact. Failing hard instead would throw away every count that did
     * succeed -- and this command's whole purpose is to make gaps visible rather
     * than silent, mirroring the degrade-not-500 posture pinned for the
     * controllers in tests/Feature/ApiFailureHandlingTest.php (#397).
     *
     * @param  array<string, string>  $failures
     */
    private function attempt(string $key, array &$failures, callable $call): mixed
    {
        try {
            return $call();
        } catch (Throwable $e) {
            $failures[$key] = sprintf('%s: %s', class_basename($e), $e->getMessage());
            $this->warn(sprintf('Capture failed for "%s": %s', $key, $e->getMessage()));

            return null;
        }
    }

    private function resolveOutPath(string $capturedAt): string
    {
        $out = (string) ($this->option('out') ?? '');
        if ($out !== '') {
            return $out;
        }

        $stamp = str_replace([':', '+'], ['', ''], $capturedAt);

        return storage_path('app/browse-counts-' . $stamp . '.json');
    }

    /**
     * @param  array<string, mixed>  $artifact
     */
    private function writeArtifact(string $path, array $artifact): void
    {
        $directory = dirname($path);
        if (! is_dir($directory)) {
            mkdir($directory, 0755, true);
        }

        file_put_contents(
            $path,
            json_encode($artifact, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n"
        );
    }

    /**
     * @param  array<string, mixed>  $artifact
     */
    private function renderArtifact(array $artifact): void
    {
        $this->line('');
        $this->line($this->describeHeader($artifact));

        $rows = [];
        foreach ($artifact['counts'] as $key => $value) {
            $rows[] = [$key, $value, $this->labelFor($artifact, $key)];
        }

        if ($rows === []) {
            $this->warn('No counts were captured.');
        } else {
            $this->table(['Count', 'Value', 'Label'], $rows);
        }

        $this->warnAboutFailures($artifact, 'this capture');
    }

    /**
     * Diff a fresh capture against an earlier one.
     *
     * Exits non-zero when anything moved, so the command is usable as a check and
     * not only as a report.
     *
     * @param  array<string, mixed>  $after
     */
    private function compare(string $path, array $after): int
    {
        if (! is_file($path)) {
            $this->error(sprintf('No artifact to compare against at %s.', $path));

            return self::FAILURE;
        }

        $before = json_decode((string) file_get_contents($path), true);
        if (! is_array($before) || ! isset($before['counts']) || ! is_array($before['counts'])) {
            $this->error(sprintf('%s is not a browse-count artifact.', $path));

            return self::FAILURE;
        }

        $this->line('');
        $this->line('Before: ' . $this->describeHeader($before));
        $this->line('After:  ' . $this->describeHeader($after));

        if (($before['api_url'] ?? null) !== ($after['api_url'] ?? null)) {
            $this->warn('The two captures came from DIFFERENT API URLs. The deltas below are not a gate measurement.');
        }
        if (($before['app_version'] ?? null) !== ($after['app_version'] ?? null)) {
            $this->warn('The two captures came from different app versions. A delta may be this app changing, not the gate.');
        }

        $keys = array_unique(array_merge(array_keys($before['counts']), array_keys($after['counts'])));
        sort($keys);

        $rows = [];
        $changed = 0;
        foreach ($keys as $key) {
            $b = $before['counts'][$key] ?? null;
            $a = $after['counts'][$key] ?? null;
            $delta = ($b === null || $a === null) ? null : $a - $b;

            if ($delta !== 0) {
                $changed++;
            }

            $rows[] = [
                $key,
                $b ?? '--',
                $a ?? '--',
                $delta === null ? '--' : sprintf('%+d', $delta),
                $this->labelFor($after, $key) ?: $this->labelFor($before, $key),
            ];
        }

        $this->table(['Count', 'Before', 'After', 'Delta', 'Label'], $rows);

        $this->warnAboutFailures($before, 'the "before" capture');
        $this->warnAboutFailures($after, 'the "after" capture');

        if ($changed === 0) {
            $this->info('No count changed between the two captures.');

            return self::SUCCESS;
        }

        $this->warn(sprintf('%d count(s) changed. Every non-zero delta needs an explanation before this is a pass.', $changed));

        return self::FAILURE;
    }

    /**
     * @param  array<string, mixed>  $artifact
     */
    private function describeHeader(array $artifact): string
    {
        return sprintf(
            'captured_at=%s api_url=%s app_version=%s',
            $artifact['captured_at'] ?? 'unknown',
            $artifact['api_url'] ?? 'unknown',
            $artifact['app_version'] ?? 'unknown'
        );
    }

    /**
     * @param  array<string, mixed>  $artifact
     */
    private function labelFor(array $artifact, string $countKey): string
    {
        if (! preg_match('/^sets\.by_genre\.([^.]+)\./', $countKey, $matches)) {
            return '';
        }

        return (string) ($artifact['labels']['genre.' . $matches[1]] ?? '');
    }

    /**
     * @param  array<string, mixed>  $artifact
     */
    private function warnAboutFailures(array $artifact, string $which): void
    {
        $failures = $artifact['failures'] ?? [];
        if (! is_array($failures) || $failures === []) {
            return;
        }

        $this->warn(sprintf('%d capture unit(s) failed in %s -- it is incomplete:', count($failures), $which));
        foreach ($failures as $key => $message) {
            $this->warn(sprintf('  %s: %s', $key, $message));
        }
    }
}
