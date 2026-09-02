<?php

use App\Http\Controllers\SetController;
use App\Http\Controllers\SetGenreController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Here is where you can register web routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| contains the "web" middleware group. Now create something great!
|
*/

Route::get('/welcome', function () {
    return view('welcome');
});

/*
 * Liveness + version endpoint. Deliberately /health and not /ping: nginx
 * matches `location ~ ^/(status|ping)$` in .docker/config/nginx-status.conf and
 * hands both straight to PHP-FPM's built-in ping page, so a Laravel route at
 * /ping would never be reached -- and repointing that location would break the
 * container healthcheck contract in .docker/prod.docker-compose.yaml.
 */
Route::get('/health', function () {
    return response()->json([
        'status' => 'ok',
        'version' => getVersion(),
        'environment' => config('app.env'),
    ]);
})->name('health');

Route::get('/', 'IndexController@index')->name('home');
Route::get('/about', 'AboutController@index')->name('about');

Route::prefix('app')->name('app.')->group(function () {
    Route::get('/', 'AppController@index')->name('index');
    Route::controller(SetController::class)->group(function () {
        Route::get('/sets', 'index')->name('sets');
        Route::get('/sets/list', 'list')->name('set.list');
        Route::get('/sets/genres/{genre}/{name?}', SetGenreController::class)->name('set.genre');
        Route::get('/sets/{id}/{name?}', 'show')->name('set');
        Route::get('/sets/{id}/{name?}/checklist', 'checklist')->name('set.checklist');
        Route::get('/sets/{id}/{name?}/subsets', 'subsets')->name('set.subsets');
    });
});
