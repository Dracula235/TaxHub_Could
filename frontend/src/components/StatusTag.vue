<script setup lang="ts">
import { computed } from 'vue'
const props=defineProps<{status:string}>()
const labels:Record<string,string>={collected:'已采集',verifying:'查验中',verified:'查验通过',verify_failed:'查验异常',pending_posting:'待入账',posted:'已入账',archived:'已归档',voided:'已作废',red_flushed:'已红冲',open:'待处理',assigned:'已指派',investigating:'调查中',closed:'已关闭'}
const tone=computed(()=>['posted','closed'].includes(props.status)?'success':['pending_posting','assigned','investigating'].includes(props.status)?'warning':['verify_failed','open'].includes(props.status)?'danger':'info')
</script>
<template><el-tag :type="tone" effect="light" round size="small"><span class="status-dot"/>{{labels[status]||status}}</el-tag></template>
