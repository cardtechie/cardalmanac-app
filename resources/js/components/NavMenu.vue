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
                        <li v-for="item in menuItems" v-bind:key="item.title" class="float-right w-16 text-right uppercase">
                            <a :href="item.link">{{ item.title }}</a>
                        </li>
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
                <v-list-item v-for="item in menuItems" v-bind:key="item.title">
                    <v-list-item-icon>
                        <v-icon>{{ item.icon }}</v-icon>
                    </v-list-item-icon>
                    <v-list-item-title><a :href="item.link">{{ item.title }}</a></v-list-item-title>
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
        menuItems: [
            {
                title: 'App',
                link: '/app',
                icon: 'mdi-cards-variant',
            },
            {
                title: 'About',
                link: '/about',
                icon: 'mdi-comment-account',
            }
        ],
    }),
}
</script>

<style lang="scss" scoped>
.v-list-item__title a {
    color: #0000008a;
}
a {
    color: #EBEBEB;
    &:hover {
        color: #C0C0C0;
    }
}
</style>
