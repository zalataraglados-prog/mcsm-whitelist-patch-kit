<script setup lang="ts">
import CardPanel from "@/components/CardPanel.vue";
import { computed } from "vue";

type WhitelistEntry = {
  id: string;
  name: string;
  uuid: string;
  source: string;
  offlineUuid: string;
  duplicateName: boolean;
  effectiveOnline: boolean;
  effectiveOffline: boolean;
  effectiveCurrent: boolean | null;
  note: string;
};

const props = defineProps<{
  config: {
    __mcsm_whitelist?: boolean;
    onlineMode?: boolean | null;
    entries?: WhitelistEntry[];
  };
}>();

const entries = computed(() => {
  if (!(props.config?.entries instanceof Array)) props.config.entries = [];
  return props.config.entries;
});

const modeText = computed(() => {
  if (props.config.onlineMode === true) return "当前服务器模式：正版模式 (online-mode=true)";
  if (props.config.onlineMode === false) return "当前服务器模式：离线模式 (online-mode=false)";
  return "当前服务器模式：未知";
});

const currentModeResult = (entry: WhitelistEntry) => {
  if (entry.effectiveCurrent == null) return "未知";
  return entry.effectiveCurrent ? "生效" : "不生效";
};

const modeResult = (value: boolean) => {
  return value ? "生效" : "不生效";
};

const addRow = () => {
  entries.value.push({
    id: `${Date.now()}-${Math.random()}`,
    name: "",
    uuid: "",
    source: "待保存后判定",
    offlineUuid: "",
    duplicateName: false,
    effectiveOnline: false,
    effectiveOffline: false,
    effectiveCurrent: null,
    note: "保存并刷新后重新判定"
  });
};

const removeRow = (targetId: string) => {
  props.config.entries = entries.value.filter((entry) => entry.id !== targetId);
};
</script>

<template>
  <a-col :span="24">
    <CardPanel style="height: 100%">
      <template #body>
        <a-typography>
          <a-typography-title :level="5">Whitelist</a-typography-title>
          <a-typography-paragraph>
            白名单按 UUID 生效。正版模式识别真实 UUID，离线模式识别按玩家名派生的离线 UUID。
          </a-typography-paragraph>
          <a-typography-paragraph>
            {{ modeText }}
          </a-typography-paragraph>
        </a-typography>
      </template>
    </CardPanel>
  </a-col>

  <a-col :span="24">
    <CardPanel style="height: 100%">
      <template #body>
        <div class="mb-12">
          <a-button type="primary" @click="addRow">新增行</a-button>
        </div>
        <a-table
          :data-source="entries"
          :pagination="false"
          row-key="id"
          :scroll="{ x: 1100 }"
          size="small"
        >
          <a-table-column title="名称" key="name" width="180">
            <template #default="{ record }">
              <a-input v-model:value="record.name" />
            </template>
          </a-table-column>
          <a-table-column title="UUID" key="uuid" width="300">
            <template #default="{ record }">
              <a-input v-model:value="record.uuid" />
            </template>
          </a-table-column>
          <a-table-column title="来源判定" key="source" width="150">
            <template #default="{ record }">
              {{ record.source }}
            </template>
          </a-table-column>
          <a-table-column title="当前模式" key="effectiveCurrent" width="100">
            <template #default="{ record }">
              {{ currentModeResult(record) }}
            </template>
          </a-table-column>
          <a-table-column title="正版模式" key="effectiveOnline" width="100">
            <template #default="{ record }">
              {{ modeResult(record.effectiveOnline) }}
            </template>
          </a-table-column>
          <a-table-column title="离线模式" key="effectiveOffline" width="100">
            <template #default="{ record }">
              {{ modeResult(record.effectiveOffline) }}
            </template>
          </a-table-column>
          <a-table-column title="备注" key="note" width="260">
            <template #default="{ record }">
              <a-typography-text :type="record.duplicateName ? 'danger' : undefined">
                {{ record.note }}
              </a-typography-text>
            </template>
          </a-table-column>
          <a-table-column title="操作" key="action" width="90" fixed="right">
            <template #default="{ record }">
              <a-button danger size="small" @click="removeRow(record.id)">删除</a-button>
            </template>
          </a-table-column>
        </a-table>
      </template>
    </CardPanel>
  </a-col>
</template>
