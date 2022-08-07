<template>
    <ul>
        <li v-for="card in checklist">
            {{ card.attributes.name }}
        </li>
    </ul>
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
    }),
    created() {
        console.log("set ID: " + this.setId);
    },
    async mounted() {
        const set = await setApi.getChecklist(this.setId);
        this.checklist = set.data.relationships.checklist;
    },
};
</script>

<style scoped></style>
