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
    public string $groupState = '';

    /**
     * Create a new component instance.
     */
    public function __construct(string $toggleOn)
    {
        switch ($toggleOn) {
            case 'list':
                $this->listState = 'active';
                break;
            case 'group':
            default:
                $this->groupState = 'active';
                break;
        }
    }

    /**
     * Get the view / contents that represent the component.
     */
    public function render(): View|Closure|string
    {
        return view('components.set-view-toggle');
    }
}
