<?php

if (!function_exists('getVersion')) {
    /**
     * Retrieve the version of the application. The version should be defined in version.env. If
     * it is not, this function will return the default version.
     *
     * In dev environments, if version.env does not define the version, the git branch will be
     * returned as the version.
     *
     * @return string
     */
    function getVersion()
    {
        $defaultVersion = 'N/A';

        if (config('app.env') == 'production') {
            // If we are in production mode, the version is most likely set in config/version.env
            return $defaultVersion;
        }

        if (!file_exists(base_path('.git'))) {
            return $defaultVersion;
        }

        // We should only get to this in dev environments
        exec('git symbolic-ref HEAD', $gitBranch);
        if (is_array($gitBranch) &&
            array_key_exists(0, $gitBranch) &&
            str_contains($gitBranch[0], 'refs/heads/')) {
            return str_replace('refs/heads/', '', $gitBranch[0]);
        }

        return $defaultVersion;
    }
}

if (!function_exists('getTitle')) {
    function getTitle(string $title = null) : string
    {
        $output = '';
        if (isset($title)) {
            $output = $title . ' | ';
        }

        $output .= config('app.name', 'Laravel');

        return trim($output);
    }
}
