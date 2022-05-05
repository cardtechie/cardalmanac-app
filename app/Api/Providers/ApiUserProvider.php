<?php

namespace App\Api\Providers;

use App\Api\Models\User;
use Exception;
use Illuminate\Contracts\Auth\Authenticatable as UserContract;
use Illuminate\Contracts\Auth\UserProvider;

class ApiUserProvider implements UserProvider
{
    /**
     * Retrieve a user by their unique identifier.
     *
     * @param mixed $identifier
     *
     * @return \Illuminate\Contracts\Auth\Authenticatable|null
     */
    public function retrieveById($identifier)
    {
        if (($user = session()->get('user'))) {
            return $user;
        }

        return null;
    }

    /**
     * Retrieve a user by their unique identifier and "remember me" token.
     *
     * @param mixed $identifier
     * @param string $token
     *
     * @return \Illuminate\Contracts\Auth\Authenticatable|null
     */
    public function retrieveByToken($identifier, $token)
    {
        return null;
    }

    /**
     * Update the "remember me" token for the given user in storage.
     *
     * @param UserContract $user
     * @param string $token
     *
     * @return void
     */
    public function updateRememberToken(UserContract $user, $token)
    {
        //
    }

    /**
     * Retrieve a user by the given credentials.
     *
     * @param array $credentials The user credentials
     *
     * @return \Illuminate\Contracts\Auth\Authenticatable|null
     */
    public function retrieveByCredentials(array $credentials)
    {
        $apiUser = new User();
        $apiUser->setUsername($credentials['email']);
        $apiUser->setPassword($credentials['password']);

        try {
            $apiUser->authenticate();
        } catch (Exception $ex) {
            //
        }

        session()->put('user', $apiUser);

        return $apiUser;
    }

    /**
     * Validate a user against the given credentials.
     *
     * @param UserContract $user The authenticable user
     * @param array $credentials The user credentials
     *f
     * @return bool
     */
    public function validateCredentials(UserContract $user, array $credentials)
    {
        $sessionUser = session()->get('user');

        if ($sessionUser->getUsername() != $credentials['email']) {
            return false;
        }

        if (!$sessionUser->isValidPassword($credentials['password'])) {
            return false;
        }

        return true;
    }
}
