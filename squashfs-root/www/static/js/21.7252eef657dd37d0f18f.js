webpackJsonp([21],{"3GnQ":function(t,e){},cLnb:function(t,e){},fHeX:function(t,e,o){"use strict";Object.defineProperty(e,"__esModule",{value:!0});var i=o("Xxa5"),s=o.n(i),a=o("//Fk"),n=o.n(a),r=o("exGp"),c=o.n(r),l=o("n8t0"),h=o("hNqL"),d={name:"home",data:function(){return{userProtocol:!1,planProtocal:!1,isselectCountry:!1,disabledPri:!0,disabledTep:!0,lang:"English",isclick:!1,selectCountry:"",lo:"",routerData:{}}},created:function(){this.disabled=this.userProtocol?0:1,this.routerInfo(),this.common.setInitLog({type:0,step:"init_web_hello"});var t=this;"-ms-scroll-limit"in document.documentElement.style&&"-ms-ime-align"in document.documentElement.style&&window.addEventListener("hashchange",function(){var e=window.location.hash.slice(1);t.$route.path!==e&&t.$router.replace(e)},!1),this.$route.query.name&&(this.lang=this.$route.query.name,this.$i18n.locale=this.$route.query.lang),this.selectCountry=this.common.getCookie("select_country")||this.$t("CLICK_SELECT"),this.selectCountry!=this.$t("CLICK_SELECT")&&(this.disabledPri=!1,this.isselectCountry=!0);var e=this.common.getCookie("userProtocal");this.userProtocol="selected"==e,this.disabledTep=this.userProtocol?0:1,this.lo=this.common.getCookie("select_country_code")?this.common.getCookie("select_country_code").toLowerCase():""},components:{CheckBox:l.a,Toast:h.a},methods:{changeUserProtocol:function(){var t=void 0;this.disabledTep=this.userProtocol?0:1,t=this.userProtocol?"selected":"other",this.common.setCookie("userProtocal",t,1/48)},start:function(){this.disabledTep||!this.isselectCountry||this.isclick||this.loginInfo()},switchlang:function(){this.$router.push({path:"/switchlang"})},loginInfo:function(){var t=this;return c()(s.a.mark(function e(){var o,i,a,r,c,l;return s.a.wrap(function(e){for(;;)switch(e.prev=e.next){case 0:return o=t.common.Encrypt.init(),i=t.common.Encrypt.oldPwd("admin"),a={username:"admin",logtype:2,nonce:o,password:i,init:1,privacy:t.planProtocal?1:0},e.next=5,t.axios.getLoginInfo(a);case 5:r=e.sent,c=t.common.getCookie("select_country_code"),l=t.$route.query.lang||"en",t.isclick=!0,r&&r.data&&0==r.data.code?(t.common.setCookie("token",r.data.token,1/48),n.a.all([t.axios.post("/api/misystem/set_location",{location:c}),t.axios.post("/api/misystem/set_language",{language:l})]).then(function(e){0==e[0].data.code&&0==e[1].data.code?t.$router.push({path:"/guide"}):(1502===e[0].data.code?t.$refs.tip.showTips(t.$t("SELECT")):t.$refs.tip.showTips(t.$t("ERROR")),t.isclick=!1,setTimeout(function(){location.reload()},1e3))},function(e){t.$refs.tip.showTips(t.$t("ERROR")),t.isclick=!1})):t.$refs.tip.showTips(r.data.msg||t.$t("ERROR"));case 10:case"end":return e.stop()}},e,t)}))()},routerInfo:function(){var t=this;return c()(s.a.mark(function e(){var o,i;return s.a.wrap(function(e){for(;;)switch(e.prev=e.next){case 0:return e.next=2,t.axios.getRouterInfo();case 2:o=e.sent,t.routerData=o.data,t.GLOBAL.hardware=o.data.hardware,t.GLOBAL.routerName=t.common.formatSsidName(o.data.name),t.GLOBAL.mac=o.data.mac,t.common.setCookie("mac",o.data.mac,1/48),t.common.setCookie("hardware",o.data.hardware,1/48),i=t.common.formatSsidName(o.data.name),t.common.setCookie("ssid_name",i,1/48);case 11:case"end":return e.stop()}},e,t)}))()},changeCountry:function(){this.$router.push({path:"/select_country",query:{lang:this.$route.query.lang,name:this.$route.query.name}})},agreement:function(){if(this.disabledPri){var t=this.$t("SELECT");this.$refs.tip.showTips(t)}else"au"==this.lo||"sg"==this.lo||"nz"==this.lo||"ke"==this.lo||"kh"==this.lo?window.location.href="../../agreement/mirouterEULA_enother.html":"ie"==this.lo||"gb"==this.lo?window.location.href="../../agreement/mirouterEULA_en.html":"eg"==this.lo||"ma"==this.lo||"jo"==this.lo?window.location.href="../../agreement/mirouterEULA_ae.html":"pe"==this.lo||"co"==this.lo||"mx"==this.lo?window.location.href="../../agreement/mirouterEULA_cl.html":"ng"==this.lo?window.location.href="../../agreement/mirouterEULA_fr.html":window.location.href="../../agreement/mirouterEULA_"+this.lo+".html"},privacy:function(){if(this.disabledPri){var t=this.$t("SELECT");this.$refs.tip.showTips(t)}else"my"==this.lo?this.$router.push({path:"/privacy_my"}):"ae"==this.lo||"ma"==this.lo||"eg"==this.lo||"jo"==this.lo?this.$router.push({path:"/privacy_ae"}):"au"==this.lo||"sg"==this.lo||"nz"==this.lo||"ke"==this.lo||"kh"==this.lo?window.location.href="../../privacy/privacy_en.html":"ie"==this.lo||"gb"==this.lo?window.location.href="../../privacy/privacy_engdpr.html":"ng"==this.lo?window.location.href="../../privacy/privacy_fr_ng.html":"pe"==this.lo||"co"==this.lo||"mx"==this.lo?window.location.href="../../privacy/privacy_cl.html":window.location.href="../../privacy/privacy_"+this.lo+".html"}}},u={render:function(){var t=this,e=t.$createElement,o=t._self._c||e;return o("div",{staticClass:"container"},[o("div",{staticClass:"title"},[o("svg",{attrs:{viewBox:"0 0 540 238",version:"1.1",xmlns:"http://www.w3.org/2000/svg","xmlns:xlink":"http://www.w3.org/1999/xlink"}},[o("defs",[o("linearGradient",{attrs:{x1:"16.7947049%",y1:"81.6162109%",x2:"71.6341146%",y2:"0%",id:"linearGradient-1"}},[o("stop",{attrs:{"stop-color":"#79F1FF",offset:"0%"}}),t._v(" "),o("stop",{attrs:{"stop-color":"#3C94FF",offset:"100%"}})],1)],1),t._v(" "),o("g",{attrs:{id:"",transform:"translate(-270.000000, -762.000000)",fill:"url(#linearGradient-1)"}},[o("g",{attrs:{id:"",transform:"translate(270.000000, 762.000000)"}},[o("path",{attrs:{d:"M434.676066,73.4997668 L434.676066,144 L427.2,144 L427.2,3.74941707 L427.2,0 L524.4,0 L524.4,7.49883414 L434.676066,7.49883414 L434.676066,66.0009327 L510.943081,66.0009327 L510.943081,73.4997668 L434.676066,73.4997668 Z M287.92913,62.9208145 L253.263382,144 L245.580291,144 L187.2,0 L194.883091,0 L249.520395,135.095414 L284.186143,53.6670294 L288.079207,44.2968444 L307.038298,0 L314.716909,0 L291.869234,53.6670294 L324.803486,135.095414 L382.316909,0 L390,0 L328.546473,144 L320.863382,144 L287.92913,62.9208145 Z M168,144 L175.2,144 L175.2,39.6 L168,39.6 L168,144 Z M168,17.7447377 L168,3.85755167 C168,1.72387917 169.611684,0 171.598927,0 C173.588316,0 175.2,1.72387917 175.2,3.85755167 L175.2,17.7447377 C175.2,19.8715421 173.588316,21.6 171.598927,21.6 C169.611684,21.6 168,19.8715421 168,17.7447377 Z M404.4,144 L411.6,144 L411.6,40.8 L404.4,40.8 L404.4,144 Z M404.4,16.7575312 L404.4,3.64246882 C404.4,1.62878158 406.011684,0 408.001073,0 C409.988316,0 411.6,1.62878158 411.6,3.64246882 L411.6,16.7575312 C411.6,18.7668692 409.988316,20.4 408.001073,20.4 C406.011684,20.4 404.4,18.7668692 404.4,16.7575312 Z M532.8,144 L540,144 L540,39.6 L532.8,39.6 L532.8,144 Z M532.8,17.7447377 L532.8,3.85755167 C532.8,1.72387917 534.409538,0 536.398927,0 C538.38617,0 540,1.72387917 540,3.85755167 L540,17.7447377 C540,19.8715421 538.38617,21.6 536.398927,21.6 C534.409538,21.6 532.8,19.8715421 532.8,17.7447377 Z M71.2874385,144 L7.50111757,13.4979014 L7.50111757,144 L0,144 L0,0 L9.20205633,0 L74.8077783,137.387595 L141.041574,0 L150,0 L150,144 L142.501118,144 L142.501118,12.5174569 L78.2565937,144 L71.2874385,144 Z",id:"Fill-1-Copy"}})])])])]),t._v(" "),o("div",{staticClass:"selectlanguage",on:{click:t.switchlang}},[t._v(t._s(t.lang))]),t._v(" "),o("div",{staticClass:"footer width100"},[o("div",{staticClass:"user"},[o("div",[o("CheckBox",{attrs:{name:"selectCountry",disabled:"disabled"},model:{value:t.isselectCountry,callback:function(e){t.isselectCountry=e},expression:"isselectCountry"}}),o("span",[t._v(t._s(t.$t("SELECT")))]),o("a",{class:{disabled:t.disabledPri},attrs:{href:"javascript:void(0)"},on:{click:t.changeCountry}},[t._v(t._s(t.selectCountry)+">")])],1),t._v(" "),o("div",[o("CheckBox",{attrs:{name:"protocal"},on:{change:t.changeUserProtocol},model:{value:t.userProtocol,callback:function(e){t.userProtocol=e},expression:"userProtocol"}}),o("span",[t._v(t._s(t.$t("home.agreewith")))]),t._v(" "),o("a",{class:{disabled:t.disabledPri},attrs:{href:"javascript:void(0)"},on:{click:t.agreement}},[t._v(t._s(t.$t("home.user_privicy")))]),t._v("\n        "+t._s(t.$t("home.user_experience_and"))),o("a",{class:{disabled:t.disabledPri},attrs:{href:"javascript:void(0)"},on:{click:t.privacy}},[t._v(t._s(t.$t("home.user_experience_plan")))])],1),t._v(" "),o("div")]),t._v(" "),o("div",{staticClass:"join"},[o("a",{staticClass:"button",class:{disabled:t.disabledTep||!t.isselectCountry||t.isclick},attrs:{href:"javascript:void(0)",disabled:t.disabledTep||!t.isselectCountry||t.isclick},on:{click:t.start}},[t._v(t._s(t.$t("home.experience_now")))])]),t._v(" "),o("div",{staticClass:"desc"},[t._v("\n      "+t._s(t.$t("home.copyright"))+"\n    ")])]),t._v(" "),o("Toast",{ref:"tip"})],1)},staticRenderFns:[]};var m=o("VU/8")(d,u,!1,function(t){o("x/Ri")},"data-v-02df2b97",null);e.default=m.exports},hNqL:function(t,e,o){"use strict";var i={name:"tip",props:{},data:function(){return{showTip:!1,desc:""}},methods:{showTips:function(t){var e=this;e.showTip=!0,e.desc=t,setTimeout(function(){e.showTip=!1},2e3)}}},s={render:function(){var t=this.$createElement;return(this._self._c||t)("div",{directives:[{name:"show",rawName:"v-show",value:this.showTip,expression:"showTip"}],staticClass:"wireless_failure"},[this._v("\n    "+this._s(this.desc)+"\n")])},staticRenderFns:[]};var a=o("VU/8")(i,s,!1,function(t){o("cLnb")},"data-v-77ab80be",null);e.a=a.exports},n8t0:function(t,e,o){"use strict";var i={name:"checkbox",model:{prop:"checked",event:"change"},props:{name:{type:String,default:""},checked:Boolean,value:String},methods:{onChange:function(t){this.$emit("change",t.target.checked)}},watch:{},mounted:function(){}},s={render:function(){var t=this,e=t.$createElement;return(t._self._c||e)("input",{staticClass:"iconfont checkbox",attrs:{name:t.name,type:"checkbox"},domProps:{value:t.value,checked:t.checked},on:{change:function(e){t.onChange(e)}}})},staticRenderFns:[]};var a=o("VU/8")(i,s,!1,function(t){o("3GnQ")},null,null);e.a=a.exports},"x/Ri":function(t,e){}});