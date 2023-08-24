<?php

namespace App\View\Components;

use Closure;
use Illuminate\Contracts\View\View;
use Illuminate\View\Component;

class SetViewToggle extends Component
{
    /**
     * The state of the list button
     *
     * @var string
     */
    public string $listState = '';

    /**
     * The state of the group by genre button
     *
     * @var string
     */
    public string $groupState = 'active';

    /**
     * Create a new component instance.
     */
    public function __construct()
    {
        //
    }

    /**
     * Get the view / contents that represent the component.
     */
    public function render(): View|Closure|string
    {
        return view('components.set-view-toggle');
    }
}
