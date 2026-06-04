<script setup lang="ts">
import { computed } from "vue";
import CardPanel from "@/components/CardPanel.vue";

type WhitelistEntry = {
  id?: string;
  name?: string;
  uuid?: string;
  banned?: boolean;
};

type WhitelistPayload = {
  __mcsm_whitelist?: boolean;
  onlineMode?: boolean | null;
  entries?: WhitelistEntry[];
  data?: {
    __mcsm_whitelist?: boolean;
    onlineMode?: boolean | null;
    entries?: WhitelistEntry[];
  };
};

const props = defineProps<{
  config: WhitelistPayload;
}>();

const payload = computed(() => {
  if (props.config?.__mcsm_whitelist) return props.config;
  if (props.config?.data?.__mcsm_whitelist) return props.config.data;
  return props.config;
});

const entries = computed<WhitelistEntry[]>({
  get() {
    if (!Array.isArray(payload.value.entries)) payload.value.entries = [];
    return payload.value.entries;
  },
  set(value) {
    payload.value.entries = value;
  }
});

const addRow = () => {
  entries.value = [
    ...entries.value,
    {
      id: `${Date.now()}-${Math.random()}`,
      name: "",
      uuid: "",
      banned: false
    }
  ];
};

const removeRow = (targetId?: string) => {
  entries.value = entries.value.filter((entry) => entry.id !== targetId);
};

const banText = (value?: boolean) => {
  return value ? "已封禁" : "未封禁";
};
</script>

<template>
  <a-col :span="24">
    <CardPanel style="height: 100%">
      <template #body>
        <a-typography>
          <a-typography-title :level="5">Whitelist</a-typography-title>
          <a-typography-paragraph>当前条目数：{{ entries.length }}</a-typography-paragraph>
          <a-typography-paragraph>“是否封禁” 只读，来源是 `banned-players.json`。</a-typography-paragraph>
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
        <a-table :data-source="entries" :pagination="false" row-key="id" :scroll="{ x: 860 }" size="small">
          <a-table-column title="名称" key="name" width="220">
            <template #default="{ record }">
              <a-input v-model:value="record.name" />
            </template>
          </a-table-column>
          <a-table-column title="UUID" key="uuid" width="360">
            <template #default="{ record }">
              <a-input v-model:value="record.uuid" />
            </template>
          </a-table-column>
          <a-table-column title="是否封禁" key="banned" width="120">
            <template #default="{ record }">
              {{ banText(record.banned) }}
            </template>
          </a-table-column>
          <a-table-column title="操作" key="action" width="100" fixed="right">
            <template #default="{ record }">
              <a-button danger size="small" @click="removeRow(record.id)">删除</a-button>
            </template>
          </a-table-column>
        </a-table>
      </template>
    </CardPanel>
  </a-col>
</template>
