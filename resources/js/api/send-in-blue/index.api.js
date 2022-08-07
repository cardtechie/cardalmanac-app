import axios from "axios";

const sendinblueApi = axios.create({
    baseURL: "https://api.sendinblue.com/v3",
});
sendinblueApi.defaults.headers.post["Accept"] = "application/json";
sendinblueApi.defaults.headers.post["Content-Type"] = "application/json";
sendinblueApi.defaults.headers.common["api-key"] =
    process.env.MIX_SENDINBLUE_API_KEY;

export default sendinblueApi;
