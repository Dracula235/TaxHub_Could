import { ref, watch, onUnmounted } from 'vue'
import { useSession } from '../stores/session'
import { queryClient } from '../api/client'
export function useEvents(){
  const session=useSession(), connected=ref(false);let source:EventSource|undefined
  const stop=watch(()=>session.tenant,tenant=>{source?.close();connected.value=false;if(!session.me)return;source=new EventSource(`/api/v1/events?tenant_id=${encodeURIComponent(tenant)}`);source.onopen=()=>{connected.value=true;void queryClient.invalidateQueries()};source.onerror=()=>{connected.value=false};for(const event of ['invoice.status_changed','posting.count_changed','risk.score_changed'])source.addEventListener(event,()=>{void queryClient.invalidateQueries()})},{immediate:true})
  onUnmounted(()=>{stop();source?.close()})
  return {connected}
}
