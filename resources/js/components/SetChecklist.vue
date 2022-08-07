<template>
    <div>
        <div v-if="loading">
            <span
                class="fa-solid fa-spinner fa-spin container text-4xl text-center"
            ></span>
        </div>
        <ul>
            <li v-for="card in checklist">
                {{ card.attributes.name }}
            </li>
        </ul>
    </div>
</template>

<script>
import setApi from "./../api/cards/set.api";

export default {
    name: "SetChecklist",
    props: {
        setId: {
            type: String,
            required: true,
        },
    },
    data: () => ({
        checklist: [],
        loading: false,
    }),
    async mounted() {
        this.loading = true;
        const set = await setApi.getChecklist(this.setId);
        this.loading = false;
        this.checklist = set.data.relationships.checklist;
    },
};
</script>

<style scoped></style>
