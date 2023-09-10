<?php

use CardTechie\TradingCardApiSdk\Models\Set;
use Diglactic\Breadcrumbs\Breadcrumbs;
use Diglactic\Breadcrumbs\Generator as BreadcrumbTrail;

// Home
Breadcrumbs::for('home', function (BreadcrumbTrail $trail) {
    $trail->push('Home', route('home'));
});

// About
Breadcrumbs::for('about', function (BreadcrumbTrail $trail) {
    $trail->parent('home');
    $trail->push('About', route('about'));
});

// App
Breadcrumbs::for('app.index', function (BreadcrumbTrail $trail) {
    $trail->push('App', route('app.index'));
});

// Sets
Breadcrumbs::for('app.sets', function (BreadcrumbTrail $trail) {
    $trail->parent('app.index');
    $trail->push('Sets', route('app.sets'));
});

// Set List
Breadcrumbs::for('app.set.list', function (BreadcrumbTrail $trail) {
    $trail->parent('app.index');
    $trail->push('Sets', route('app.set.list'));
});

// Set
Breadcrumbs::for('app.set', function (BreadcrumbTrail $trail, Set $set) {
    $trail->parent('app.sets');
    $trail->push($set->name, route('app.set', ['id' => $set->id, 'name' => str()->slug($set->name)]));
});

// Set Checklist
Breadcrumbs::for('app.set.checklist', function (BreadcrumbTrail $trail, Set $set) {
    $trail->parent('app.set', $set);
    $trail->push('Checklist', route('app.set.checklist', ['id' => $set->id, 'name' => str()->slug($set->name)]));
});
