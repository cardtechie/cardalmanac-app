<template>
    <p>Set checklist component</p>
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
    created() {
        console.log("set ID: " + this.setId);
    },
    async mounted() {
        const set = await setApi.getChecklist(this.setId);
        console.log(set);
    },
};
</script>

<style scoped></style>
