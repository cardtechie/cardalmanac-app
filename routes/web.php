<?php

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

Route::get('/app', 'AppController@index');
Route::get('/app/sets', 'SetController@index')->name('sets');
Route::get('/app/sets/{id}/{name?}', 'SetController@show');
Route::get('/app/sets/{id}/checklist', 'SetController@checklist');
Route::get('/app/sets/{id}/subsets', 'SetController@subsets');
