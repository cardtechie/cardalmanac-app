<?php

namespace App\Api;

use ArrayAccess;
use Countable;
use Illuminate\Contracts\Pagination\Paginator as PaginatorContract;
use Illuminate\Contracts\Support\Arrayable;
use Illuminate\Contracts\Support\Jsonable;
use Illuminate\Pagination\AbstractPaginator;
use IteratorAggregate;
use JsonSerializable;

/**
 * Class ApiPaginator
 */
class ApiPaginator extends AbstractPaginator implements
    Arrayable,
    ArrayAccess,
    Countable,
    IteratorAggregate,
    Jsonable,
    JsonSerializable,
    PaginatorContract
{
    /**
     * The URL for the next page, or null.
     *
     * @return string|null
     */
    public function nextPageUrl() : ?string
    {
        // TODO: Implement nextPageUrl() method.
    }

    /**
     * Determine if there are more items in the data store.
     *
     * @return bool
     */
    public function hasMorePages() : bool
    {
        // TODO: Implement hasMorePages() method.
    }

    /**
     * Render the paginator using a given view.
     *
     * @param  string|null  $view
     * @param  array  $data
     *
     * @return string
     *
     * @phpcsSuppress SlevomatCodingStandard.Functions.UnusedParameter.UnusedParameter
     */
    public function render($view = null, $data = []) : string
    {
        // TODO: Implement render() method.
    }
}
