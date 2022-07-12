<template>
    <ul class="nav nav-tabs flex flex-col md:flex-row flex-wrap list-none border-b-0 pl-0 mb-4" id="tabs-tab" role="tablist">
        <li class="nav-item" role="presentation">
            <a href="/sets/881302a7-c133-4e3b-88dd-4139af505bea"
               class="nav-link block font-medium text-xs leading-tight uppercase border-x-0 border-t-0 border-b-2 border-transparent px-6 py-3 my-2 hover:border-transparent hover:bg-gray-100 focus:border-transparent active"
               id="tabs-details-tab"
               role="tab"
               aria-controls="tabs-details"
               aria-selected="true"
            >Details</a>
        </li>
        <li class="nav-item" role="presentation">
            <a href="/sets/881302a7-c133-4e3b-88dd-4139af505bea/checklist"
               class="nav-link block font-medium text-xs leading-tight uppercase border-x-0 border-t-0 border-b-2 border-transparent px-6 py-3 my-2 hover:border-transparent hover:bg-gray-100 focus:border-transparent"
               id="tabs-checklist-tab"
               role="tab"
               aria-controls="tabs-checklist"
               aria-selected="false"
            >Checklist</a>
        </li>
        <li class="nav-item" role="presentation">
            <a href="/sets/881302a7-c133-4e3b-88dd-4139af505bea/subsets"
               class="nav-link block font-medium text-xs leading-tight uppercase border-x-0 border-t-0 border-b-2 border-transparent px-6 py-3 my-2 hover:border-transparent hover:bg-gray-100 focus:border-transparent"
               id="tabs-subsets-tab"
               role="tab"
               aria-controls="tabs-subsets"
               aria-selected="false"
            >Subsets</a>
        </li>
    </ul>
</template>

<script>
export default {
    name: 'SetTabs'
}
</script>

<style scoped>

</style>
