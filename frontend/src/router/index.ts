import { createRouter, createWebHistory } from 'vue-router'
import { useSession } from '../stores/session'
import WorkbenchLayout from '../layouts/WorkbenchLayout.vue'

export const router=createRouter({history:createWebHistory(),routes:[
  {path:'/login',component:()=>import('../views/LoginView.vue')},
  {path:'/',component:WorkbenchLayout,children:[
    {path:'',redirect:'/dashboard'},
    {path:'dashboard',component:()=>import('../views/DashboardView.vue'),meta:{title:'角色仪表盘'}},
    {path:'invoices/:id?',component:()=>import('../views/InvoicesView.vue'),meta:{title:'发票中心'}},
    {path:'posting',component:()=>import('../views/InvoicesView.vue'),meta:{title:'智能入账'}},
    {path:'risks',component:()=>import('../views/RisksView.vue'),meta:{title:'风险管控'}},
    {path:'reimbursements',component:()=>import('../views/ReimbursementsView.vue'),meta:{title:'费用报销'}},
    ...Object.entries({archives:'电子档案',filings:'税务申报',compliance:'合规检查',reports:'财务报表',integrations:'应用集成',org:'组织权限',settings:'系统设置'}).map(([path,title])=>({path,component:()=>import('../views/PlaceholderView.vue'),meta:{title}})),
    {path:':pathMatch(.*)*',component:()=>import('../views/PlaceholderView.vue'),meta:{title:'页面不存在'}}
  ]}
]})
router.beforeEach(async to=>{const session=useSession();if(!session.me)await session.restore();if(to.path!=='/login'&&!session.me)return {path:'/login',query:{redirect:to.fullPath}};if(to.path==='/login'&&session.me)return '/dashboard';return true})
window.addEventListener('session-expired',()=>{useSession().clear();void router.replace({path:'/login',query:{redirect:router.currentRoute.value.fullPath}})})
