<template>
  <div id="mailing-list-form">
    <form
      v-on:submit.prevent="submitForm"
      novalidate
      v-if="state !== 'success'"
    >
      <label for="email">Email</label>
      <p v-if="errors.length" v-bind:class="[errors.length ? 'error' : '']">
        {{ errors[0] }}
      </p>
      <input
        id="email"
        v-model="email"
        type="email"
        name="email"
        placeholder="Email Address"
        v-bind:class="[errors.length ? 'alert' : '']"
        @blur="errors = []"
        style="background-color: #fff"
      />
      <button :disabled="isDisabled">Subscribe</button>
    </form>
    <p v-if="state === 'success'" class="pt-12">
      Almost there! Now check your inbox to confirm your subscription so you can
      receive notifications as you requested.
    </p>
  </div>
</template>

<script>
import { pushEvent } from "../analytics";

export default {
  name: "MailingListForm",
  props: {
    // Where this form is embedded, sent as a GA4 event parameter so the same
    // component can be tracked separately per placement.
    ctaLocation: {
      type: String,
      default: "unknown",
    },
  },
  data() {
    return {
      regex:
        /^(([^<>()[\]\\.,;:\s@"]+(\.[^<>()[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/,
      errors: [],
      email: null,
      state: null,
    };
  },
  computed: {
    isDisabled() {
      return this.state === "submit";
    },
  },
  methods: {
    async submitForm() {
      this.state = "submit";
      this.errors = [];
      if (!this.validEmail(this.email)) {
        this.errors.push("Please provide a valid email address");
        this.state = null;
      } else {
        try {
          // Posted to an internal Laravel route, which holds the Brevo API
          // key server-side (#426). window.axios is configured in
          // resources/js/bootstrap.js and sends the XSRF token automatically.
          await window.axios.post("/newsletter/subscribe", {
            email: this.email,
          });
          pushEvent("newsletter_signup", {
            cta_location: this.ctaLocation,
          });
          this.state = "success";
        } catch (e) {
          this.errors.push(
            "Unable to add your email address to the mailing list."
          );
          this.state = null;
        }
      }
    },
    validEmail(email) {
      return this.regex.test(email);
    },
  },
};
</script>

<style lang="scss" scoped>
#mailing-list-form {
  position: relative;
  input,
  button {
    border-radius: 5px;
    height: 50px;

    &:disabled {
      background-color: #95999c;
      cursor: inherit;
    }
  }
  input {
    border: 1px solid #2a2a2a;
    padding: 0 12px;
    width: 100%;
    &::placeholder {
      color: #95999c;
      font-family: "Poppins", sans-serif;
    }
  }
  button {
    margin-top: 20px;
    width: 35%;
    background-color: #427aa1;
    color: #fff;
    font-weight: bold;
    border: none;
    -webkit-box-shadow: -9px 6px 15px 3px rgba(99, 52, 52, 0.24);
    box-shadow: -9px 6px 15px 3px rgba(99, 52, 52, 0.24);
    transition: 0.4s all;
    &:hover {
      -webkit-box-shadow: -9px 6px 15px -2px rgba(99, 52, 52, 0.24);
      box-shadow: -9px 6px 15px -2px rgba(99, 52, 52, 0.24);
    }
  }
  label {
    font-size: 1px;
  }
  p {
    font-size: 0.9rem;

    &.error {
      padding-bottom: 10px;
      color: #dc3545;
    }
  }
  .alert {
    border: 2px solid #dc3545;
  }
}
@media only screen and (max-width: 720px) {
  #mailing-list-form {
    margin-bottom: 40px;
  }
}
@media only screen and (max-width: 480px) {
  #mailing-list-form {
    .error-icon {
      right: 30px;
    }
  }
}
</style>
