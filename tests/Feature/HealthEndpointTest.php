<?php

namespace Tests\Feature;

use Tests\TestCase;

/**
 * Coverage for #47: before this, nothing in the running application reported
 * which build was deployed. /health is the operational surface for that.
 *
 * Deliberately not /ping — nginx (.docker/config/nginx-status.conf) matches
 * `^/(status|ping)$` and hands those to PHP-FPM's own ping page, so Laravel
 * never sees them.
 */
class HealthEndpointTest extends TestCase
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

    public function test_it_reports_status_version_and_environment(): void
    {
        $response = $this->get('/health');

        $response->assertOk();
        $response->assertJsonStructure(['status', 'version', 'environment']);
        $response->assertJsonPath('status', 'ok');
        $response->assertJsonPath('environment', config('app.env'));

        $version = $response->json('version');
        $this->assertIsString($version);
        $this->assertNotSame('', $version);
    }

    /**
     * The whole point of the change: a version stamped into the image has to
     * come back out over HTTP, without shell access to the host.
     */
    public function test_it_reports_the_version_stamped_into_the_image(): void
    {
        file_put_contents($this->versionFile, "1.4.7\n");
        getVersion(true);

        $this->get('/health')->assertOk()->assertJsonPath('version', '1.4.7');
    }
}
