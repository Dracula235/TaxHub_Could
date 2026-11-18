import { defineStore } from 'pinia'
import { ref } from 'vue'
import { api, type Model, queryClient } from '../api/client'
export const useSession = defineStore('session',()=>{
  const me=ref<Model<'Me'>|null>(null), tenant=ref('demo-a'), collapsed=ref(false)
  const can=(permission:string)=>me.value?.permissions.includes(permission)??false
  async function restore(){try{me.value=await api('/me','get');if(!me.value.tenants.some(t=>t.id===tenant.value))tenant.value=me.value.tenants[0]?.id||''}catch{me.value=null}}
  async function login(account:string,password:string){me.value=await api('/auth/login','post',{body:{account,password}});tenant.value=me.value.tenants[0]?.id||''}
  async function logout(){await api('/auth/logout','post');clear()}
  function clear(){me.value=null;queryClient.clear()}
  return {me,tenant,collapsed,can,restore,login,logout,clear}
})
