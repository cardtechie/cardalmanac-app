<template>
    <p>Set checklist component</p>
</template>

<script>
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
};
</script>

<style scoped></style>
