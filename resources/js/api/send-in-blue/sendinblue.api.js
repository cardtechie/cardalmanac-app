import sendinblueApi from './index.api';

const sibApi = {
  subscribe: async (email) => {
    const body = {
      email: email,
      includeListIds: [
        4, // CardTechie Notifications
      ],
      templateId: 1,
      redirectionUrl: 'https://cardalmanac.com/complete-newsletter-signup',
    };
    await sendinblueApi.post('contacts/doubleOptinConfirmation', body);
  },
};

export default sibApi;
