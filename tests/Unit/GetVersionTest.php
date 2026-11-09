<?php

namespace Tests\Unit;

use Tests\TestCase;

/**
 * Coverage for #47: getVersion() returned the literal 'N/A' in production and
 * pointed at a config/version.env file that never existed. These lock the
 * precedence chain documented on resolveApplicationVersion().
 *
 * Extends the framework TestCase rather than PHPUnit's: the helper resolves
 * paths through base_path() and reads env(), both of which need a booted app.
 */
class GetVersionTest extends TestCase
{
    private string $versionFile;

    /** Contents of a VERSION file that already existed, so it can be restored. */
    private ?string $preExistingContents = null;

    protected function setUp(): void
    {
        parent::setUp();

        $this->versionFile = base_path('VERSION');
        $this->preExistingContents = is_file($this->versionFile)
            ? (string) file_get_contents($this->versionFile)
            : null;

        $this->forgetAppVersion();
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

        $this->forgetAppVersion();

        parent::tearDown();
    }

    public function test_the_app_version_environment_variable_wins_over_the_stamped_file(): void
    {
        $this->stampVersionFile("9.9.9\n");
        $this->setAppVersion('1.2.3-from-env');

        $this->assertSame('1.2.3-from-env', getVersion(true));
    }

    public function test_the_app_version_environment_variable_is_trimmed(): void
    {
        $this->setAppVersion("  1.2.3  \n");

        $this->assertSame('1.2.3', getVersion(true));
    }

    public function test_a_blank_app_version_environment_variable_falls_through_to_the_file(): void
    {
        $this->stampVersionFile("0.4.2\n");
        $this->setAppVersion('   ');

        $this->assertSame('0.4.2', getVersion(true));
    }

    public function test_it_reads_the_trimmed_first_line_of_the_stamped_version_file(): void
    {
        $this->stampVersionFile("  0.4.2  \nignored trailing content\n");

        $this->assertSame('0.4.2', getVersion(true));
    }

    /**
     * A blank file must not shadow the remaining rungs — otherwise a failed
     * build-arg substitution would render an empty version string rather than
     * degrading to something legible.
     */
    public function test_a_blank_version_file_falls_through_to_the_next_rung(): void
    {
        $this->removeVersionFile();
        $withoutFile = getVersion(true);

        $this->stampVersionFile("   \n");

        $this->assertSame($withoutFile, getVersion(true));
    }

    public function test_it_never_resolves_to_an_empty_string_when_nothing_is_stamped(): void
    {
        $this->removeVersionFile();
        $version = getVersion(true);

        $this->assertIsString($version);
        $this->assertNotSame('', $version);

        // .git is excluded by .dockerignore, so inside any built image the git
        // rung cannot fire and 'N/A' is the only possible answer. Locally the
        // repo is present, so the branch name is returned instead.
        if (!file_exists(base_path('.git'))) {
            $this->assertSame('N/A', $version);
        }
    }

    public function test_the_resolved_version_is_memoized_until_refreshed(): void
    {
        $this->setAppVersion('first');
        $this->assertSame('first', getVersion(true));

        $this->setAppVersion('second');
        $this->assertSame('first', getVersion(), 'the resolved version should be memoized');

        $this->assertSame('second', getVersion(true));
    }

    private function stampVersionFile(string $contents): void
    {
        file_put_contents($this->versionFile, $contents);
    }

    private function removeVersionFile(): void
    {
        if (is_file($this->versionFile)) {
            unlink($this->versionFile);
        }
    }

    private function setAppVersion(string $value): void
    {
        putenv('APP_VERSION=' . $value);
        $_ENV['APP_VERSION'] = $value;
        $_SERVER['APP_VERSION'] = $value;
    }

    /**
     * Drop the environment override and the memoized value so each case starts
     * from the same state.
     */
    private function forgetAppVersion(): void
    {
        putenv('APP_VERSION');
        unset($_ENV['APP_VERSION'], $_SERVER['APP_VERSION']);

        getVersion(true);
    }
}
