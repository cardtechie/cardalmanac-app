<?php

use App\Http\Controllers\SetController;
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

Route::prefix('app')->name('app.')->group(function () {
    Route::get('/', 'AppController@index')->name('index');
    Route::controller(SetController::class)->group(function () {
        Route::get('/sets', 'index')->name('sets');
        Route::get('/sets/{id}/{name?}', 'show')->name('set');
        Route::get('/sets/{id}/{name?}/checklist', 'checklist')->name('set.checklist');
        Route::get('/sets/{id}/{name?}/subsets', 'subsets')->name('set.subsets');
    });
});
