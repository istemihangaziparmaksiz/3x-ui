<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { message, Modal } from 'ant-design-vue';
import {
  CloudDownloadOutlined,
  CopyOutlined,
  ReloadOutlined,
  SecurityScanOutlined,
  UserAddOutlined,
  DeleteOutlined,
} from '@ant-design/icons-vue';

import AppSidebar from '@/components/AppSidebar.vue';
import { HttpUtil } from '@/utils';
import { theme as themeState, antdThemeConfig } from '@/composables/useTheme.js';

const { t } = useI18n();

const basePath = window.X_UI_BASE_PATH || '';
const requestUri = window.location.pathname;

const tabKey = ref('overview');
const loading = ref(false);
const status = ref(null);
const scriptOutput = ref('');
const busyBadvpn = ref(false);
const busyStunnel = ref(false);
const busyConnOn = ref(false);
const busyConnOff = ref(false);
const busyBadvpnUnit = ref(false);
const busyStunnelSample = ref(false);
const busyDaemonReload = ref(false);
const busySshList = ref(false);
const busySshAdd = ref(false);
const busySshDel = ref(false);

const sshUsers = ref([]);
const newUsername = ref('');
const newPassword = ref('');
const delUsername = ref('');
const udpgwPort = ref(7300);

const sshColumns = computed(() => [
  { title: t('pages.darkssh.sshUsername'), dataIndex: 'name', key: 'name' },
]);

function sshTableData() {
  return sshUsers.value.map((name) => ({ key: name, name }));
}

async function loadStatus() {
  loading.value = true;
  try {
    const msg = await HttpUtil.get('/panel/darkssh/status');
    if (msg?.success && msg.obj) {
      status.value = msg.obj;
    }
  } finally {
    loading.value = false;
  }
}

function applyScriptResult(msg) {
  const out = msg?.obj?.output ?? '';
  scriptOutput.value = out;
  if (msg?.success) {
    message.success(t('pages.darkssh.scriptFinished'));
  } else if (out) {
    message.warning(t('pages.darkssh.scriptFinishedWithErrors'));
  }
}

async function runInstall(url, busyRef) {
  busyRef.value = true;
  try {
    const msg = await HttpUtil.post(url, {});
    applyScriptResult(msg);
    await loadStatus();
  } finally {
    busyRef.value = false;
  }
}

async function runPost(url, body, busyRef) {
  busyRef.value = true;
  try {
    const msg = await HttpUtil.post(url, body || {});
    applyScriptResult(msg);
    await loadStatus();
  } finally {
    busyRef.value = false;
  }
}

async function loadSshUsers() {
  busySshList.value = true;
  try {
    const msg = await HttpUtil.post('/panel/darkssh/ssh/users/list', {});
    if (msg?.success && Array.isArray(msg.obj?.users)) {
      sshUsers.value = msg.obj.users;
    } else if (!msg?.success) {
      message.error(t('pages.darkssh.toasts.listUsers'));
    }
  } finally {
    busySshList.value = false;
  }
}

async function addSshUser() {
  await runPost(
    '/panel/darkssh/ssh/user/add',
    { subUsername: newUsername.value, subPassword: newPassword.value },
    busySshAdd,
  );
  newPassword.value = '';
  await loadSshUsers();
}

function confirmDeleteSshUser() {
  const name = delUsername.value.trim();
  if (!name) {
    message.warning(t('pages.darkssh.sshUsername'));
    return;
  }
  Modal.confirm({
    title: t('pages.darkssh.sshDelete'),
    content: t('pages.darkssh.sshDeleteConfirm', { name }),
    okType: 'danger',
    onOk: async () => {
      await runPost('/panel/darkssh/ssh/user/del', { subUsername: name }, busySshDel);
      delUsername.value = '';
      await loadSshUsers();
    },
  });
}

async function installBadvpnSystemd() {
  await runPost(
    '/panel/darkssh/badvpn/systemd/install',
    { udpgwPort: udpgwPort.value },
    busyBadvpnUnit,
  );
}

async function copyInstallCmd() {
  const text = t('pages.darkssh.remoteInstallCmd');
  try {
    await navigator.clipboard.writeText(text);
    message.success(t('copySuccess'));
  } catch (_e) {
    message.error(t('fail'));
  }
}

onMounted(() => {
  loadStatus();
  loadSshUsers();
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

          <a-tabs v-model:activeKey="tabKey" class="darkssh-tabs">
            <a-tab-pane key="overview" :tab="t('pages.darkssh.tabOverview')">
              <a-space direction="vertical" size="large" style="width: 100%">
                <a-card :title="t('pages.darkssh.remoteInstallTitle')">
                  <a-typography-paragraph type="secondary">
                    {{ t('pages.darkssh.remoteInstallDesc') }}
                  </a-typography-paragraph>
                  <a-space>
                    <a-button type="primary" @click="copyInstallCmd">
                      <template #icon>
                        <CopyOutlined />
                      </template>
                      {{ t('copy') }}
                    </a-button>
                  </a-space>
                  <pre class="install-cmd">{{ t('pages.darkssh.remoteInstallCmd') }}</pre>
                </a-card>

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
                    <a-descriptions-item :label="t('pages.darkssh.ipv4Forward')">
                      {{ status.ipv4Forward ? t('pages.darkssh.yes') : t('pages.darkssh.no') }}
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
              </a-space>
            </a-tab-pane>

            <a-tab-pane key="ssh" :tab="t('pages.darkssh.tabSsh')">
              <a-space direction="vertical" size="large" style="width: 100%">
                <a-card :title="t('pages.darkssh.sshListTitle')">
                  <a-space>
                    <a-button :loading="busySshList" @click="loadSshUsers">
                      <template #icon>
                        <ReloadOutlined />
                      </template>
                      {{ t('pages.darkssh.sshListRefresh') }}
                    </a-button>
                  </a-space>
                  <a-table
                    class="ssh-table"
                    size="small"
                    :columns="sshColumns"
                    :data-source="sshTableData()"
                    :pagination="false"
                  />
                </a-card>

                <a-card :title="t('pages.darkssh.sshAddTitle')">
                  <a-typography-paragraph type="secondary">
                    {{ t('pages.darkssh.sshUsernameHint') }}
                  </a-typography-paragraph>
                  <a-space direction="vertical" style="width: 100%; max-width: 400px">
                    <a-input v-model:value="newUsername" :placeholder="t('pages.darkssh.sshUsername')" />
                    <a-input-password v-model:value="newPassword" :placeholder="t('pages.darkssh.sshPassword')" />
                    <a-typography-text type="secondary">
                      {{ t('pages.darkssh.sshPasswordHint') }}
                    </a-typography-text>
                    <a-button
                      type="primary"
                      :disabled="!status?.scriptsAllowed"
                      :loading="busySshAdd"
                      @click="addSshUser"
                    >
                      <template #icon>
                        <UserAddOutlined />
                      </template>
                      {{ t('pages.darkssh.sshAddUser') }}
                    </a-button>
                  </a-space>
                </a-card>

                <a-card :title="t('pages.darkssh.sshDelTitle')">
                  <a-typography-paragraph type="secondary">
                    {{ t('pages.darkssh.sshDelHint') }}
                  </a-typography-paragraph>
                  <a-space>
                    <a-input v-model:value="delUsername" :placeholder="t('pages.darkssh.sshUsername')" style="width: 220px" />
                    <a-button
                      danger
                      :disabled="!status?.scriptsAllowed"
                      :loading="busySshDel"
                      @click="confirmDeleteSshUser"
                    >
                      <template #icon>
                        <DeleteOutlined />
                      </template>
                      {{ t('pages.darkssh.sshDelete') }}
                    </a-button>
                  </a-space>
                </a-card>
              </a-space>
            </a-tab-pane>

            <a-tab-pane key="conn" :tab="t('pages.darkssh.tabConn')">
              <a-card :title="t('pages.darkssh.connTitle')">
                <a-typography-paragraph type="secondary">
                  {{ t('pages.darkssh.connDesc') }}
                </a-typography-paragraph>
                <a-space>
                  <a-button
                    type="primary"
                    :disabled="!status?.scriptsAllowed"
                    :loading="busyConnOn"
                    @click="runInstall('/panel/darkssh/conn/ipforward/on', busyConnOn)"
                  >
                    {{ t('pages.darkssh.connOn') }}
                  </a-button>
                  <a-button
                    danger
                    :disabled="!status?.scriptsAllowed"
                    :loading="busyConnOff"
                    @click="runInstall('/panel/darkssh/conn/ipforward/off', busyConnOff)"
                  >
                    {{ t('pages.darkssh.connOff') }}
                  </a-button>
                </a-space>
              </a-card>
            </a-tab-pane>

            <a-tab-pane key="services" :tab="t('pages.darkssh.tabServices')">
              <a-space direction="vertical" size="large" style="width: 100%">
                <a-card :title="t('pages.darkssh.svcBadvpnTitle')">
                  <a-typography-paragraph type="secondary">
                    {{ t('pages.darkssh.svcBadvpnDesc') }}
                  </a-typography-paragraph>
                  <a-space align="center" wrap>
                    <span>{{ t('pages.darkssh.svcUdpgwPort') }}</span>
                    <a-input-number v-model:value="udpgwPort" :min="1024" :max="65535" />
                    <a-button
                      type="primary"
                      :disabled="!status?.scriptsAllowed"
                      :loading="busyBadvpnUnit"
                      @click="installBadvpnSystemd"
                    >
                      {{ t('pages.darkssh.svcInstallBadvpnUnit') }}
                    </a-button>
                  </a-space>
                </a-card>

                <a-card :title="t('pages.darkssh.svcStunnelTitle')">
                  <a-typography-paragraph type="secondary">
                    {{ t('pages.darkssh.svcStunnelDesc') }}
                  </a-typography-paragraph>
                  <a-button
                    :disabled="!status?.scriptsAllowed"
                    :loading="busyStunnelSample"
                    @click="runInstall('/panel/darkssh/stunnel/sample/conf', busyStunnelSample)"
                  >
                    {{ t('pages.darkssh.svcStunnelWrite') }}
                  </a-button>
                </a-card>

                <a-card :title="t('pages.darkssh.svcReloadTitle')">
                  <a-typography-paragraph type="secondary">
                    {{ t('pages.darkssh.svcReloadDesc') }}
                  </a-typography-paragraph>
                  <a-button
                    :disabled="!status?.scriptsAllowed"
                    :loading="busyDaemonReload"
                    @click="runInstall('/panel/darkssh/systemd/daemon-reload', busyDaemonReload)"
                  >
                    {{ t('pages.darkssh.svcDaemonReload') }}
                  </a-button>
                </a-card>
              </a-space>
            </a-tab-pane>
          </a-tabs>

          <a-card v-if="scriptOutput" :title="t('pages.darkssh.lastOutput')" class="output-card">
            <pre class="script-output">{{ scriptOutput }}</pre>
          </a-card>
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

.darkssh-tabs {
  max-width: 960px;
}

.ssh-table {
  margin-top: 12px;
}

.install-cmd {
  margin-top: 12px;
  padding: 12px;
  background: rgba(0, 0, 0, 0.04);
  border-radius: 6px;
  font-size: 12px;
  white-space: pre-wrap;
  word-break: break-all;
}

.output-card {
  margin-top: 20px;
  max-width: 960px;
}

.script-output {
  white-space: pre-wrap;
  word-break: break-word;
  margin: 0;
  font-size: 12px;
  line-height: 1.5;
}
</style>
