<template>
    <div>
        <v-app-bar
            color="#004E98"
            dark
            height="60"
        >
            <div class="container flex">
                <h1 class="flex-auto"><a href="/">Card Almanac</a></h1>
                <v-app-bar-nav-icon @click="drawer = true" class="flex-auto float-right"></v-app-bar-nav-icon>
            </div>
        </v-app-bar
            color="#004E98">

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

<style lang="scss" scoped>
a {
    color: #EBEBEB;
    &:hover {
        color: #C0C0C0;
    }
}
</style>
