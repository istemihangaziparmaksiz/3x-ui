<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { message } from 'ant-design-vue';
import {
  CloudDownloadOutlined,
  ReloadOutlined,
  SecurityScanOutlined,
} from '@ant-design/icons-vue';

import AppSidebar from '@/components/AppSidebar.vue';
import { HttpUtil } from '@/utils';
import { theme as themeState, antdThemeConfig } from '@/composables/useTheme.js';

const { t } = useI18n();

const basePath = window.X_UI_BASE_PATH || '';
const requestUri = window.location.pathname;

const loading = ref(false);
const status = ref(null);
const scriptOutput = ref('');
const busyBadvpn = ref(false);
const busyStunnel = ref(false);

async function loadStatus() {
  loading.value = true;
  scriptOutput.value = '';
  try {
    const msg = await HttpUtil.get('/panel/darkssh/status');
    if (msg?.success && msg.obj) {
      status.value = msg.obj;
    }
  } finally {
    loading.value = false;
  }
}

async function runInstall(url, busyRef) {
  busyRef.value = true;
  scriptOutput.value = '';
  try {
    const msg = await HttpUtil.post(url, {});
    const out = msg?.obj?.output ?? '';
    scriptOutput.value = out;
    if (msg?.success) {
      message.success(t('pages.darkssh.scriptFinished'));
    } else if (out) {
      message.warning(t('pages.darkssh.scriptFinishedWithErrors'));
    }
    await loadStatus();
  } finally {
    busyRef.value = false;
  }
}

onMounted(() => {
  loadStatus();
});
</script>

<template>
  <a-config-provider :theme="antdThemeConfig">
    <a-layout class="page-root" :class="{ 'ultra-dark': themeState.isUltra }">
      <AppSidebar :base-path="basePath" :request-uri="requestUri" />
      <a-layout>
        <a-layout-content class="page-content">
          <a-typography-title :level="4" class="page-title">
            <SecurityScanOutlined aria-hidden="true" />
            {{ t('pages.darkssh.title') }}
          </a-typography-title>
          <a-typography-paragraph type="secondary">
            {{ t('pages.darkssh.intro') }}
          </a-typography-paragraph>

          <a-space direction="vertical" size="large" style="width: 100%">
            <a-card :title="t('pages.darkssh.overview')">
              <a-space>
                <a-button type="primary" :loading="loading" @click="loadStatus">
                  <template #icon>
                    <ReloadOutlined />
                  </template>
                  {{ t('pages.darkssh.refresh') }}
                </a-button>
              </a-space>
              <a-descriptions v-if="status" bordered size="small" class="status-desc" :column="1">
                <a-descriptions-item :label="t('pages.darkssh.hostname')">
                  {{ status.hostname || '—' }}
                </a-descriptions-item>
                <a-descriptions-item :label="t('pages.darkssh.kernel')">
                  {{ status.kernel || '—' }}
                </a-descriptions-item>
                <a-descriptions-item :label="t('pages.darkssh.os')">
                  {{ status.os || '—' }}
                </a-descriptions-item>
                <a-descriptions-item :label="t('pages.darkssh.badvpnUdpgw')">
                  {{ status.badvpnUdpgw ? t('pages.darkssh.yes') : t('pages.darkssh.no') }}
                </a-descriptions-item>
                <a-descriptions-item :label="t('pages.darkssh.stunnel')">
                  {{ status.stunnel ? t('pages.darkssh.yes') : t('pages.darkssh.no') }}
                </a-descriptions-item>
                <a-descriptions-item :label="t('pages.darkssh.scriptsAllowed')">
                  {{ status.scriptsAllowed ? t('pages.darkssh.yes') : t('pages.darkssh.no') }}
                </a-descriptions-item>
              </a-descriptions>
            </a-card>

            <a-card :title="t('pages.darkssh.badvpnCard')">
              <a-typography-paragraph type="secondary">
                {{ t('pages.darkssh.badvpnDesc') }}
              </a-typography-paragraph>
              <a-button
                type="primary"
                :disabled="!status?.scriptsAllowed"
                :loading="busyBadvpn"
                @click="runInstall('/panel/darkssh/badvpn/install', busyBadvpn)"
              >
                <template #icon>
                  <CloudDownloadOutlined />
                </template>
                {{ t('pages.darkssh.runInstall') }}
              </a-button>
            </a-card>

            <a-card :title="t('pages.darkssh.stunnelCard')">
              <a-typography-paragraph type="secondary">
                {{ t('pages.darkssh.stunnelDesc') }}
              </a-typography-paragraph>
              <a-button
                type="primary"
                :disabled="!status?.scriptsAllowed"
                :loading="busyStunnel"
                @click="runInstall('/panel/darkssh/stunnel/install', busyStunnel)"
              >
                <template #icon>
                  <CloudDownloadOutlined />
                </template>
                {{ t('pages.darkssh.runInstall') }}
              </a-button>
            </a-card>

            <a-card v-if="scriptOutput" :title="t('pages.darkssh.lastOutput')">
              <pre class="script-output">{{ scriptOutput }}</pre>
            </a-card>
          </a-space>
        </a-layout-content>
      </a-layout>
    </a-layout>
  </a-config-provider>
</template>

<style scoped>
.page-root {
  min-height: 100vh;
}

.page-content {
  padding: 16px 24px 48px;
}

.page-title {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px !important;
}

.status-desc {
  margin-top: 16px;
  max-width: 720px;
}

.script-output {
  white-space: pre-wrap;
  word-break: break-word;
  margin: 0;
  font-size: 12px;
  line-height: 1.5;
}
</style>
