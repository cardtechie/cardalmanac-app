import axios from "axios";

const setUrl = "/api/sets";

const setApi = {
  searchSets: async (filters) => {
    let url = setUrl;

    const search = Object.keys(filters)
      .map(function (key) {
        return key + "=" + filters[key];
      })
      .join("&");
    if (search) {
      url += "?" + search;
    }

    return await axios.get(url);
  },
  getSet: async (id) => {
    let url = `${setUrl}/${id}?include=`;
    return await axios.get(url);
  },
  getChecklist: async (id) => {
    let url = `${setUrl}/${id}?include=checklist`;
    return await axios.get(url);
  },
};

export default setApi;
