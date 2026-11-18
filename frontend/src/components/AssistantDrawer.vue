<script setup lang="ts">
import { ref } from 'vue'
defineProps<{modelValue:boolean}>();defineEmits<{'update:modelValue':[boolean]}>()
const question=ref(''),messages=ref<{role:string;text:string}[]>([])
function ask(text=question.value){if(!text.trim())return;messages.value.push({role:'user',text});messages.value.push({role:'assistant',text:text.includes('风险')?'演示指引：进入「风险管控」，查看关联发票及异常原因。完成核查后，可按指派、调查、关闭的顺序记录处置过程。':text.includes('申报')?'当前申报页面为骨架占位。正式申报需从台账生成底稿，完成勾稽校验，并能追溯到原始发票。':'演示指引：在「发票中心」模拟导入一张样例票据，完成查验后生成入账建议。展开三项依据，人工确认后采纳，即可查看凭证。'});question.value=''}
</script>
<template><el-drawer :model-value="modelValue" title="税枢 AI 助手" size="min(450px, 100vw)" @update:model-value="$emit('update:modelValue',$event)"><div class="assistant-intro"><span class="ai-orb">✧</span><h2>让财税工作，更从容。</h2><p>固定演示问答 · 未连接大模型</p></div><el-button v-for="q in ['如何完成一张票的入账？','如何处理发票风险？','申报前需要做什么？']" :key="q" class="prompt-button" @click="ask(q)">{{q}} ↗</el-button><div class="chat-message" :class="m.role" v-for="(m,i) in messages" :key="i">{{m.text}}</div><template #footer><form class="chat-input" @submit.prevent="ask()"><el-input v-model="question" aria-label="输入问题" placeholder="输入你想了解的问题" maxlength="500"/><el-button native-type="submit" type="primary" :disabled="!question.trim()">发送</el-button></form></template></el-drawer></template>
