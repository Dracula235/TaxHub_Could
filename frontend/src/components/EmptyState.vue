<script setup lang="ts">withDefaults(defineProps<{title?:string;description?:string}>(),{title:'该模块将在 P1 开放',description:'当前版本专注票据采集、查验与入账工作流。'})</script>
<template><div class="empty-state"><div class="empty-symbol">▤</div><h3>{{title}}</h3><p>{{description}}</p><slot /></div></template>
