import { createApp } from "vue";
import Example from "./components/ExampleComponent";
import MailingListForm from "./components/MailingListForm";
import NavDrawer from "./components/NavDrawer";
import SetChecklist from "./components/SetChecklist";
import { bindAnalyticsEvents } from "./analytics";
import vuetify from "./vuetify";

/**
 * First we will load all of this project's JavaScript dependencies which
 * includes Vue and other libraries. It is a great starting point when
 * building robust, powerful web applications using Vue and Laravel.
 */

require("./bootstrap");

window.Vue = require("vue").default;

/**
 * The following block of code may be used to automatically register your
 * Vue components. It will recursively scan this directory for the Vue
 * components and automatically register them with their "basename".
 *
 * Eg. ./components/ExampleComponent.vue -> <example-component></example-component>
 */

// const files = require.context('./', true, /\.vue$/i)
// files.keys().map(key => Vue.component(key.split('/').pop().split('.')[0], files(key).default))

/**
 * Delegated GA4 click tracking for any element carrying data-analytics-event.
 * Bound before Vue boots so a mount failure cannot take tracking down with it.
 */
bindAnalyticsEvents();

const app = createApp({});
app.component("example-component", Example);
app.component("mailing-list-form", MailingListForm);
app.component("nav-drawer", NavDrawer);
app.component("set-checklist", SetChecklist);
app.use(vuetify);
app.mount("#app");
