<?php

// Note: Laravel will automatically resolve `Breadcrumbs::` without
// this import. This is nice for IDE syntax and refactoring.
use Diglactic\Breadcrumbs\Breadcrumbs;

// This import is also not required, and you could replace `BreadcrumbTrail $trail`
//  with `$trail`. This is nice for IDE type checking and completion.
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

// Set
Breadcrumbs::for('app.set', function (BreadcrumbTrail $trail, string $setId) {
    $trail->parent('app.sets');
    $trail->push('Set', route('app.set', ['id' => $setId, 'name' => 'blah']));
    //$trail->push('About', route('about'));
});

// Set Checklist
Breadcrumbs::for('app.set.checklist', function (BreadcrumbTrail $trail, string $setId) {
    $trail->parent('app.set', $setId);
    $trail->push('Checklist', route('app.set.checklist', ['id' => $setId, 'name' => 'blah']));
});
