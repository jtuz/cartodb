import { shallowMount, createLocalVue } from '@vue/test-utils';
import StackedQuotaWidget from 'new-dashboard/pages/Home/QuotaSection/StackedQuotaWidget';
import Vuex from 'vuex';

const localVue = createLocalVue();
localVue.use(Vuex);

let store = new Vuex.Store({
  state: {
    config: {
      upgrade_url: 'https://test-upgrade-link.com'
    }
  }
});

const $t = key => key;

describe('StackedQuotaWidget.vue', () => {
  it('should render correct contents', () => {
    const quotaWidget = shallowMount(StackedQuotaWidget, {
      propsData: {
        name: 'Widget test',
        quotaType: 'quota',
        availableQuota: 1234,
        usedQuota: 40,
        unit: 'GB',
        helpLink: 'https://test-help-link.com'
      }
    });

    expect(quotaWidget).toMatchSnapshot();
  });

  it('should render correctly compact widget', () => {
    const quotaWidget = shallowMount(StackedQuotaWidget, {
      propsData: {
        name: 'Another test',
        quotaType: 'credits',
        availableQuota: 1234,
        usedQuota: 12,
        mode: 'compact',
        helpLink: 'https://test-help-link.com'
      }
    });

    expect(quotaWidget).toMatchSnapshot();
  });

  it('should render a disabled  widget with warning', () => {
    const quotaWidget = shallowMount(StackedQuotaWidget, {
      store,
      localVue,
      propsData: {
        name: 'Another test',
        quotaType: 'credits',
        availableQuota: 0,
        usedQuota: 0,
        helpLink: 'https://test-help-link.com',
        isDisabled: true
      },
      mocks: {
        $t
      }
    });

    expect(quotaWidget).toMatchSnapshot();
  });

  it('should render warning if the storage remaining quota is negative', () => {
    const quotaWidget = shallowMount(StackedQuotaWidget, {
      propsData: {
        name: 'Another test',
        quotaType: 'quota',
        availableQuota: 262144000,
        usedQuota: 289722368,
        unit: 'MB'
      },
      mocks: {
        $t
      }
    });

    expect(quotaWidget).toMatchSnapshot();
  });

  it('should render warning bar if used ammount is over 60% and under 90%', () => {
    const quotaWidget = shallowMount(StackedQuotaWidget, {
      propsData: {
        name: 'My test',
        quotaType: 'test',
        availableQuota: 1000,
        usedQuota: 610,
        helpLink: 'https://test-help-link.com',
        qualitative: true
      }
    });

    expect(quotaWidget).toMatchSnapshot();
  });

  it('should render problem bar if used ammount is over 90%', () => {
    const quotaWidget = shallowMount(StackedQuotaWidget, {
      propsData: {
        name: 'My test',
        quotaType: 'test',
        availableQuota: 1000,
        usedQuota: 932,
        helpLink: 'https://test-help-link.com',
        qualitative: true
      }
    });

    expect(quotaWidget).toMatchSnapshot();
  });

  it('should render multiple bars', () => {
    const quotaWidget = shallowMount(StackedQuotaWidget, {
      propsData: {
        name: 'My test',
        quotaType: 'test',
        availableQuota: 1000,
        usedQuota: [{ value: 224 }, { value: 100 }],
        helpLink: 'https://test-help-link.com'
      }
    });

    expect(quotaWidget).toMatchSnapshot();
  });

  it('should render unlimited bar if unlimited is true', () => {
    const quotaWidget = shallowMount(StackedQuotaWidget, {
      propsData: {
        name: 'My test',
        quotaType: 'test',
        usedQuota: 400,
        helpLink: 'https://test-help-link.com',
        unlimited: true
      }
    });

    expect(quotaWidget).toMatchSnapshot();
  });

  describe('Computed', () => {
    it('should return correct remaining quota', () => {
      const quotaWidget = shallowMount(StackedQuotaWidget, {
        propsData: {
          name: 'My test',
          quotaType: 'test',
          availableQuota: 350,
          usedQuota: [{ value: 224 }, { value: 100 }]
        }
      });

      const percent = quotaWidget.vm.remainingQuota;

      expect(percent).toBe(26);
    });

    it('should not crash and return 100 when the available capacity is 0', () => {
      const quotaWidget = shallowMount(StackedQuotaWidget, {
        propsData: {
          name: 'My test',
          quotaType: 'test',
          availableQuota: 0,
          usedQuota: 0
        },
        mocks: {
          $t
        }
      });

      const percent = quotaWidget.vm.remainingQuota;

      expect(percent).toBe(0);
    });

    it('should return correct status of the quota', () => {
      const quotaWidgetGood = shallowMount(StackedQuotaWidget, {
        propsData: {
          name: 'My test',
          quotaType: 'test',
          availableQuota: 100,
          usedQuota: 50
        }
      });
      const quotaWidgetWarning = shallowMount(StackedQuotaWidget, {
        propsData: {
          name: 'My test',
          quotaType: 'test',
          availableQuota: 100,
          usedQuota: 61.4
        }
      });
      const quotaWidgetProblem = shallowMount(StackedQuotaWidget, {
        propsData: {
          name: 'My test',
          quotaType: 'test',
          availableQuota: 100,
          usedQuota: 90.1
        }
      });

      const statusGood = quotaWidgetGood.vm.getStatusBar;
      const statusWarning = quotaWidgetWarning.vm.getStatusBar;
      const statusProblem = quotaWidgetProblem.vm.getStatusBar;

      expect(statusGood).toBe('good');
      expect(statusWarning).toBe('warning');
      expect(statusProblem).toBe('problem');
    });
  });

  describe('Methods', () => {
    it('should round decimals correctly correct percent', () => {
      const quotaWidget = shallowMount(StackedQuotaWidget, {
        propsData: {
          name: 'My test',
          quotaType: 'test',
          availableQuota: 350,
          usedQuota: 224
        }
      });

      const value1 = quotaWidget.vm.roundOneDecimal(0);
      const value2 = quotaWidget.vm.roundOneDecimal(0.1234);
      const value3 = quotaWidget.vm.roundOneDecimal(120.2);
      const value4 = quotaWidget.vm.roundOneDecimal(129.0);
      const value5 = quotaWidget.vm.roundOneDecimal(45.8);
      const value6 = quotaWidget.vm.roundOneDecimal(45.26);

      expect(String(value1)).toBe('0');
      expect(String(value2)).toBe('0.1');
      expect(String(value3)).toBe('120.2');
      expect(String(value4)).toBe('129');
      expect(String(value5)).toBe('45.8');
      expect(String(value6)).toBe('45.3');
    });
  });
});
