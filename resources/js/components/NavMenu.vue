<template>
    <div>
        <v-app-bar-nav-icon @click="drawer = true"></v-app-bar-nav-icon>

        <v-navigation-drawer
            v-model="drawer"
            absolute
            temporary
            right
        >
            <v-list dense>
                <v-list-item>
                    <v-list-item-content>
                        <v-list-item-title>App</v-list-item-title>
                    </v-list-item-content>
                </v-list-item>
            </v-list>
        </v-navigation-drawer>
    </div>
</template>

<script>
export default {
    name: 'NavMenu',
    data: () => ({
        drawer: false,
    }),
}
</script>

<style scoped>

</style>
