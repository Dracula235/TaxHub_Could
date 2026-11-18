<script setup lang="ts">defineProps<{modelValue:boolean;title:string;size?:string}>();defineEmits<{'update:modelValue':[boolean]}>()</script>
<template><el-drawer :model-value="modelValue" :title="title" :size="size||'min(680px, 100vw)'" destroy-on-close @update:model-value="$emit('update:modelValue',$event)"><slot/><template #footer><slot name="footer"/></template></el-drawer></template>
