import { createApp } from 'vue'
import { createPinia } from 'pinia'
import { VueQueryPlugin } from '@tanstack/vue-query'
import ElementPlus from 'element-plus'
import zhCn from 'element-plus/es/locale/lang/zh-cn'
import 'element-plus/dist/index.css'
import './theme/index.scss'
import App from './App.vue'
import { router } from './router'
import { queryClient } from './api/client'

createApp(App).use(createPinia()).use(router).use(VueQueryPlugin,{queryClient}).use(ElementPlus,{locale:zhCn}).mount('#app')
