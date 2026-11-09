<?php

namespace Tests\Feature;

use Tests\TestCase;

/**
 * Coverage for #47: the footer interpolated config('app.version'), a key
 * config/app.php never defined, so it silently rendered an empty string. It now
 * renders getVersion(), which is also what makes the helper reachable from a
 * real code path rather than being dead code.
 */
class FooterVersionTest extends TestCase
{
    private string $versionFile;

    private ?string $preExistingContents = null;

    protected function setUp(): void
    {
        parent::setUp();

        $this->versionFile = base_path('VERSION');
        $this->preExistingContents = is_file($this->versionFile)
            ? (string) file_get_contents($this->versionFile)
            : null;
    }

    protected function tearDown(): void
    {
        if ($this->preExistingContents === null) {
            if (is_file($this->versionFile)) {
                unlink($this->versionFile);
            }
        } else {
            file_put_contents($this->versionFile, $this->preExistingContents);
        }

        getVersion(true);

        parent::tearDown();
    }

    public function test_the_footer_renders_the_resolved_version(): void
    {
        file_put_contents($this->versionFile, "2.5.1\n");
        getVersion(true);

        $html = view('partials.footer')->render();

        $this->assertStringContainsString('2.5.1', $html);
    }

    public function test_the_footer_no_longer_reads_the_undefined_app_version_config_key(): void
    {
        $this->assertNull(
            config('app.version'),
            'config/app.php defines no version key; the footer must not depend on one'
        );

        $source = file_get_contents(resource_path('views/partials/footer.blade.php'));

        $this->assertStringNotContainsString("config('app.version')", $source);
        $this->assertStringContainsString('getVersion()', $source);
    }
}
