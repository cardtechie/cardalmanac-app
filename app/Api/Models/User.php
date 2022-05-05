<?php

namespace App\Api\Models;

use App\Api\TradingCardApi;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Support\Facades\Http;

/**
 * Class User
 */
class User extends Authenticatable
{
    private $username;
    private $password;
    private $token;
    private $refreshToken;

    /**
     * Set the username.
     *
     * @param $username
     *
     * @return User
     */
    public function setUsername($username) : User
    {
        $this->username = $username;

        return $this;
    }

    /**
     * Get the username.
     *
     * @return string
     */
    public function getUsername() : string
    {
        return $this->username;
    }

    /**
     * Set the password.
     *
     * @param $password
     *
     * @return User
     */
    public function setPassword($password) : User
    {
        $this->password = $password;

        return $this;
    }

    public function isValidPassword($password) : bool
    {
        if ($password === $this->password) {
            return true;
        }

        return false;
    }

    /**
     * Attempt to get a token from the trading card api. An exception will be returned
     * if authentication fails for any reason. Otherwise, the token will be saved
     * to this class.
     */
    public function authenticate()
    {
        $api = new TradingCardApi();
        $url = $api->url . '/oauth/token';

        $response = Http::withOptions([
            'debug' => true,
            'verify' => $api->verifySsl,
        ])->withHeaders([
            'accept' => 'application/json',
        ])->asForm()->post($url, [
            'grant_type' => 'password',
            'client_id' => config('api.client-id'),
            'client_secret' => config('api.client-secret'),
            'scopes' => '',
            'username' => $this->username,
            'password' => $this->password,
        ])->json();

        $this->token = $response['access_token'];
        $this->refreshToken = $response['refresh_token'];

        return $this;
    }
}
