<template>
    <div>
        <v-app-bar
            color="#004E98"
            dark
            height="60"
        >
            <div class="container flex">
                <h1 class="flex-auto"><a href="/">Card Almanac</a></h1>
                <div class="float-right block lg:hidden">
                    <v-app-bar-nav-icon @click="drawer = true"></v-app-bar-nav-icon>
                </div>
                <nav class="flex-auto w-1/2 mt-3 lg:block hidden">
                    <ul class="float-right">
                        <li class="float-right w-16 text-right uppercase"><a href="/about">About</a></li>
                        <li class="float-right w-16 text-right uppercase"><a href="/app">App</a></li>
                    </ul>
                </nav>
            </div>
        </v-app-bar>

        <v-navigation-drawer
            v-model="drawer"
            absolute
            temporary
            right
        >
            <v-list dense>
                <v-list-item>
                    <v-list-item-icon>
                        <v-icon>mdi-home</v-icon>
                    </v-list-item-icon>
                    <v-list-item-title><a href="/">Home</a></v-list-item-title>
                </v-list-item>
                <v-list-item>
                    <v-list-item-icon>
                        <v-icon>mdi-cards-variant</v-icon>
                    </v-list-item-icon>
                    <v-list-item-content>
                        <v-list-item-title><a href="/app">App</a></v-list-item-title>
                    </v-list-item-content>
                </v-list-item>
                <v-list-item>
                    <v-list-item-icon>
                        <v-icon>mdi-comment-account</v-icon>
                    </v-list-item-icon>
                    <v-list-item-content>
                        <v-list-item-title><a href="/about">About</a></v-list-item-title>
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
