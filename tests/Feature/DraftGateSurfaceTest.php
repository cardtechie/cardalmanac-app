<?php

namespace Tests\Feature;

use Tests\TestCase;

/**
 * Architecture-fitness guard for #437.
 *
 * The Trading Card API gates players, teams and player-teams by publication
 * status (cardtechie/tradingcardapi-api#2383), and the /v1/stats totals change
 * under cardtechie/tradingcardapi-api#2435. This app consumes none of those
 * today, which is why the expected browse-count delta is zero.
 *
 * That is a fact about the current tree, not a permanent property. This test
 * pins it, so a future change that starts reading a gated entity re-opens the
 * #437 verification loudly instead of silently invalidating its conclusion.
 */
class DraftGateSurfaceTest extends TestCase
{
    /**
     * Source trees a visitor-facing read could plausibly live in.
     *
     * @var list<string>
     */
    private const SCANNED_DIRECTORIES = [
        'app',
        'config',
        'helpers',
        'routes',
        'resources/views',
        'resources/js',
        'resources/content',
    ];

    /**
     * @var list<string>
     */
    private const SCANNED_EXTENSIONS = ['php', 'js', 'vue', 'md'];

    /**
     * Known hits that are prose or unrelated boilerplate, not API reads.
     *
     * Each entry is allow-listed by exact path so a NEW reference anywhere --
     * including a second one in the same file's directory -- still fails.
     *
     * @var array<string, string>
     */
    private const ALLOWED = [
        // Marketing prose naming player and team among the resources the almanac
        // covers. Describes the product, reads no endpoint.
        'resources/views/about.blade.php' => 'marketing prose, not an API read',

        // Launch blog post listing "Cards by player and team" as a capability.
        // Prose again -- the page renders from markdown, not from /v1/players.
        'resources/content/blog/introducing-card-almanac.md' => 'blog prose, not an API read',

        // Laravel's stock bootstrap.js comment ("allows your team to easily build
        // robust real-time web applications"). Framework boilerplate; the word is
        // the English one, not the entity.
        'resources/js/bootstrap.js' => 'framework boilerplate comment',
    ];

    /**
     * Entities gated by api#2383, plus the stats surface changed by api#2435.
     *
     * @var list<string>
     */
    private const GATED_PATTERNS = [
        '/\bplayer(s|team|teams)?\b/i',
        '/\bteam(s)?\b/i',
        '/v1\/stats/i',
    ];

    /**
     * @return list<string> repo-relative paths
     */
    private function scannedFiles(): array
    {
        $files = [];

        foreach (self::SCANNED_DIRECTORIES as $directory) {
            $absolute = base_path($directory);
            if (! is_dir($absolute)) {
                continue;
            }

            $iterator = new \RecursiveIteratorIterator(
                new \RecursiveDirectoryIterator($absolute, \FilesystemIterator::SKIP_DOTS)
            );

            foreach ($iterator as $file) {
                if (! $file->isFile()) {
                    continue;
                }

                if (! in_array(strtolower($file->getExtension()), self::SCANNED_EXTENSIONS, true)) {
                    continue;
                }

                $files[] = $directory . '/' . ltrim(
                    str_replace($absolute, '', $file->getPathname()),
                    DIRECTORY_SEPARATOR
                );
            }
        }

        sort($files);

        return $files;
    }

    public function test_the_app_reads_no_entity_gated_by_the_draft_status_gate(): void
    {
        $offenders = [];

        foreach ($this->scannedFiles() as $relative) {
            if (array_key_exists($relative, self::ALLOWED)) {
                continue;
            }

            $contents = (string) file_get_contents(base_path($relative));

            foreach (self::GATED_PATTERNS as $pattern) {
                if (preg_match($pattern, $contents) === 1) {
                    $offenders[] = $relative;
                    break;
                }
            }
        }

        $this->assertSame(
            [],
            $offenders,
            "This app gained a reference to an entity gated by the API's draft-status gate "
            . "(players, teams, player-teams via cardtechie/tradingcardapi-api#2383, or /v1/stats "
            . "via cardtechie/tradingcardapi-api#2435).\n\n"
            . "The browse-count verification in cardtechie/cardalmanac-app#437 concluded that this "
            . "app surfaces no gated entity, so the expected delta is zero. That conclusion no "
            . "longer holds and the verification has to be re-run:\n\n"
            . "  php artisan browse:capture-counts --out=storage/app/browse-counts-before.json\n"
            . "  # enable STATUS_GATE_ON_CARDABLE_ENABLED, then:\n"
            . "  php artisan browse:capture-counts --compare=storage/app/browse-counts-before.json\n\n"
            . "See docs/DRAFT-STATUS-GATE-VERIFICATION.md. If the new reference is prose rather "
            . "than an API read, allow-list it by exact path in self::ALLOWED with a comment "
            . "saying why.\n\nOffending file(s): " . implode(', ', $offenders)
        );
    }

    public function test_every_allow_listed_path_still_exists(): void
    {
        // An allow-list entry for a deleted file is dead weight that would silently
        // start excusing a future file at the same path.
        foreach (array_keys(self::ALLOWED) as $relative) {
            $this->assertFileExists(
                base_path($relative),
                sprintf('Allow-listed path %s no longer exists -- drop it from self::ALLOWED.', $relative)
            );
        }
    }
}
