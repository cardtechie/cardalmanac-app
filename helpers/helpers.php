<?php

if (!function_exists('resolveApplicationVersion')) {
    /**
     * Resolve the running application's version without memoization.
     *
     * Internal to getVersion(); call that instead. Precedence, highest first:
     *
     *   1. The APP_VERSION environment variable, when it holds a non-empty
     *      value. This is an override for deployments that would rather inject
     *      the version through the container environment than rebuild an image.
     *      It is deliberately not the primary mechanism: PHP-FPM's clear_env
     *      defaults to `yes`, so a container environment variable is not
     *      guaranteed to reach PHP.
     *   2. The VERSION file at the project root. The Dockerfile's runtime stage
     *      writes the release version calculated by build/version.sh into it, so
     *      every shipped image carries the release it was cut from.
     *   3. The checked-out git branch. .git is excluded by .dockerignore, so
     *      this rung only ever fires during local development.
     *   4. 'N/A' when nothing above yields a value.
     *
     * @return string
     */
    function resolveApplicationVersion(): string
    {
        $fromEnvironment = env('APP_VERSION');
        if (is_string($fromEnvironment) && trim($fromEnvironment) !== '') {
            return trim($fromEnvironment);
        }

        $versionFile = base_path('VERSION');
        if (is_file($versionFile) && is_readable($versionFile)) {
            // Suppressed deliberately: a race between the checks above and this
            // read should fall through to the next rung rather than emit a
            // warning into a rendered page.
            $contents = @file_get_contents($versionFile);
            if (is_string($contents)) {
                $lines = preg_split('/\r\n|\r|\n/', $contents, 2);
                $firstLine = trim((string) ($lines[0] ?? ''));
                if ($firstLine !== '') {
                    return $firstLine;
                }
            }
        }

        if (function_exists('exec') && file_exists(base_path('.git'))) {
            $gitBranch = [];
            // Suppressed deliberately, and exec() is guarded by function_exists
            // above: hardened hosts disable it via disable_functions, and a
            // shell that is missing or refuses to run should fall through to
            // the next rung rather than emit a warning into a rendered page.
            @exec('git symbolic-ref HEAD', $gitBranch);
            if (array_key_exists(0, $gitBranch) &&
                str_contains($gitBranch[0], 'refs/heads/')) {
                return str_replace('refs/heads/', '', $gitBranch[0]);
            }
        }

        return 'N/A';
    }
}

if (!function_exists('getVersion')) {
    /**
     * Retrieve the version of the application.
     *
     * See resolveApplicationVersion() for the precedence chain. The resolved
     * value is memoized for the life of the request, so calling this from a
     * view or a route costs at most one file read (plus, in local development
     * only, one `git symbolic-ref`).
     *
     * @param  bool  $refresh  Recompute rather than return the memoized value.
     *                         The test suite uses this to exercise each rung.
     * @return string
     */
    function getVersion($refresh = false): string
    {
        static $resolved = null;

        if ($refresh) {
            $resolved = null;
        }

        if ($resolved === null) {
            $resolved = resolveApplicationVersion();
        }

        return $resolved;
    }
}

if (!function_exists('renderTitle')) {
    function renderTitle(string $title = null) : string
    {
        $output = '';
        if (isset($title)) {
            $output = $title . ' | ';
        }

        $output .= config('app.name', 'Laravel');

        return trim($output);
    }
}
