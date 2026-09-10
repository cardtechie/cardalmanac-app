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

Route::get('/', 'IndexController@index')->name('home');
Route::get('/about', 'AboutController@index')->name('about');

/*
 * Newsletter double opt-in (#426). The Brevo API key is held server-side by
 * NewsletterController; nothing about it reaches the JS bundle. The subscribe
 * endpoint is unauthenticated and spends a third-party quota, so it is
 * throttled by the 'newsletter' limiter in RouteServiceProvider.
 *
 * Declared with the relative "Controller@method" form, like the routes above:
 * RouteServiceProvider groups this file under the App\Http\Controllers
 * namespace, which is prepended to string controller references.
 */
Route::post('/newsletter/subscribe', 'NewsletterController@subscribe')
    ->middleware('throttle:newsletter')
    ->name('newsletter.subscribe');
Route::get('/complete-newsletter-signup', 'NewsletterController@confirmed')
    ->name('newsletter.confirmed');

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
