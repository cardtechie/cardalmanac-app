<template>
  <div>
    <div class="container flex">
      <div class="float-right block lg:hidden">
        <v-app-bar-nav-icon @click="drawer = true"></v-app-bar-nav-icon>
      </div>
    </div>

    <div v-show="drawer">
      <v-navigation-drawer
        v-model="drawer"
        absolute
        temporary
        right
        height="inherit"
      >
        <v-list-item>
          <v-list-item-content>
            <v-list-item-title>
              <div class="title flex-auto float-left pt-1">{{ title }}</div>
              <div
                class="close flex-auto float-right text-2xl p-1"
                @click="drawer = false"
              >
                X
              </div>
            </v-list-item-title>
          </v-list-item-content>
        </v-list-item>

        <v-divider></v-divider>
        <v-list dense>
          <v-list-item>
            <v-list-item-icon>
              <v-icon>mdi-home</v-icon>
            </v-list-item-icon>
            <v-list-item-title class="pl-2">
              <a :href="this.baseUrl" @click="drawer = false">Home</a>
            </v-list-item-title>
          </v-list-item>
          <v-list-item v-for="item in menuItems" v-bind:key="item.title">
            <v-list-item-icon>
              <v-icon>{{ item.icon }}</v-icon>
            </v-list-item-icon>
            <v-list-item-title class="pl-2">
              <a :href="item.link" @click="drawer = false">{{ item.title }}</a>
            </v-list-item-title>
          </v-list-item>
        </v-list>
      </v-navigation-drawer>
    </div>
  </div>
</template>

<script>
export default {
  name: "NavDrawer",
  props: {
    title: {
      type: String,
      required: true,
    },
  },
  data: () => ({
    drawer: false,
    menuItems: [
      {
        title: "App",
        link: process.env.MIX_APP_URL + "/app",
        icon: "mdi-cards-variant",
      },
      {
        title: "About",
        link: process.env.MIX_APP_URL + "/about",
        icon: "mdi-comment-account",
      },
      {
        title: "Blog",
        link: process.env.MIX_APP_URL + "/blog",
        icon: "mdi-rss-box",
      },
    ],
    baseUrl: process.env.MIX_APP_URL,
  }),
};
</script>

<style lang="scss" scoped>
.v-btn > .v-btn__content .v-icon {
  color: #fff;
}
.v-list-item__title {
  a {
    color: #000036;
  }
  .title {
    font-size: 1.625rem;
    line-height: 1.75rem;
    font-weight: bold;
    color: #000036;
  }
  .close {
  }
}
</style>
