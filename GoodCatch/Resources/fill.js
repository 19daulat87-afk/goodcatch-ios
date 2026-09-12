(() => {
 if(window.yycBusy) return;
 window.yycBusy=true; window.yycResult='';
 const job = (async function(){
          const missing = [];
          const sleep = ms => new Promise(r => setTimeout(r, ms));
          const norm = v => String(v||'').replace(/[{}]/g,'').replace(/\s+/g,' ').trim().toLowerCase();
          const labelText = v => norm(v).replace(/[\s:*]+$/g,'');
          async function waitFor(find) { for(let i=0;i<25;i++){const value=find();if(value)return value;await sleep(200);}return null; }
          function labelledField(wanted) {
            const fields=[...document.querySelectorAll('input:not([type="checkbox"]):not([type="hidden"]),textarea')];
            return fields.find(el=>{
              const labels=[el.getAttribute('aria-label'), ...(el.labels||[])].map(x=>typeof x==='string'?x:x?.textContent);
              const ids=(el.getAttribute('aria-labelledby')||'').split(/\s+/).filter(Boolean);
              labels.push(ids.map(id=>document.getElementById(id)?.textContent||'').join(' '));
              return labels.some(x=>labelText(x)===wanted);
            }) || [...document.querySelectorAll('[data-field-name],fieldset')].filter(section=>{
              const label=section.querySelector('label,legend,[class*="label"],[class*="Label"]');
              return labelText(label?.textContent)===wanted;
            }).map(section=>section.querySelector('textarea,input[type="text"],input:not([type])')).find(Boolean);
          }

          function setVal(el,val){
            if(!el) return false;
            const proto = el.tagName === 'TEXTAREA'
              ? HTMLTextAreaElement.prototype
              : HTMLInputElement.prototype;
            const d = Object.getOwnPropertyDescriptor(proto,'value');
            if(d && d.set) d.set.call(el,val); else el.value=val;
            ['input','change','blur'].forEach(t => el.dispatchEvent(new Event(t,{bubbles:true})));
            return true;
          }

          function fillText(selector, value) { if(!setVal(document.querySelector(selector),value)) missing.push(selector); }
          const visible = el => {
            if(!el) return false;
            const s=getComputedStyle(el), b=el.getBoundingClientRect();
            return s.display!=='none' && s.visibility!=='hidden' && b.width>0 && b.height>0;
          };
          const matches = (actual,wanted) => {
            const a=norm(actual), w=norm(wanted);
            return a===w || (/^[1-4]$/.test(w) && (a.startsWith(w+'-')||a.startsWith(w+' ')));
          };
          function press(el){
            if(!el || (el.tagName==='BUTTON' && el.type!=='button')) return false;
            el.click(); return true;
          }
          function fieldFor(label,fieldName){
            const exact=fieldName && document.querySelector('[data-field-name="'+fieldName+'"]');
            if(exact) return exact;
            const target=norm(label);
            const heading=[...document.querySelectorAll('label,legend,h1,h2,h3,h4,[class*="label"],[class*="Label"]')]
              .filter(visible).find(el=>{const t=norm(el.innerText||el.textContent); return t===target||t.startsWith(target+' *');});
            return heading && (heading.closest('[data-field-name],fieldset,[class*="field"],[class*="Field"]') || heading.parentElement);
          }
          async function dropdown(label,wanted,fieldName){
            const field=fieldFor(label,fieldName);
            if(!field) {missing.push(label); return false;}
            const candidates=[...field.querySelectorAll('[role="combobox"],input[aria-haspopup="listbox"],button[aria-haspopup="listbox"],input[aria-label],button[aria-label],input[type="text"],button')].filter(visible);
            const control=candidates.find(el=>el.getAttribute('role')==='combobox'||el.getAttribute('aria-haspopup')==='listbox'||norm(el.getAttribute('aria-label')).includes('toggle')) || candidates[0];
            if(!control) {missing.push(label); return false;}
            if(matches(control.value||control.innerText||control.textContent,wanted)) return true;
            control.scrollIntoView({block:'center'}); await sleep(250);
            const wrap=control.closest('[role="combobox"]')||control.parentElement;
            press((wrap&&wrap.querySelector('button[aria-label*="Toggle" i],button[aria-label*="open" i],button'))||control);
            await sleep(600);
            const options=[...document.querySelectorAll('[role="option"],[role="listbox"] li,[role="menuitem"],[data-client-id*="option"],[class*="option"],[class*="Option"]')].filter(visible);
            const option=options.find(el=>matches(el.innerText||el.textContent||el.getAttribute('aria-label'),wanted));
            if(option){ option.scrollIntoView({block:'nearest'}); press(option); await sleep(450); return true; }
            control.blur();
            missing.push(label); return false;
          }

          async function selectSite(){
            const wanted=window.yycConfig.site;
            // SITE is virtualized: search first, then click the rendered result.
            const selected=()=>{
              const combo=fieldFor('SITE','vXwLJ9NZ')?.querySelector('[role="combobox"]');
              return combo && combo.getAttribute('aria-expanded')!=='true' &&
                !!combo.querySelector('button[aria-label="Clear selection"]') && matches(combo.textContent,wanted);
            };
            for(let attempt=0;attempt<2;attempt++){
              if(selected())return true;
              const field=await waitFor(()=>fieldFor('SITE','vXwLJ9NZ'));
              const input=field?.querySelector('input[type="text"]');
              const combo=input?.closest('[role="combobox"]');
              if(!input || !combo || input.disabled)continue;
              input.scrollIntoView({block:'center'}); input.focus();
              if(combo.getAttribute('aria-expanded')!=='true')press(combo.querySelector('button[aria-label="Toggle menu"]')||input);
              Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(input,wanted);
              input.dispatchEvent(new Event('input',{bubbles:true}));
              input.dispatchEvent(new Event('change',{bubbles:true}));
              const option=await waitFor(()=>{
                const current=fieldFor('SITE','vXwLJ9NZ')?.querySelector('[role="combobox"]');
                const menu=document.getElementById(current?.getAttribute('aria-controls')||input.getAttribute('aria-controls')||'');
                return menu && [...menu.querySelectorAll('[role="option"]')].find(el=>visible(el)&&matches(el.textContent,wanted));
              });
              if(option){press(option);if(await waitFor(selected))return true;}
            }
            missing.push('SITE (select '+wanted+')');return false;
          }

          const bodyText = norm(document.body && document.body.innerText);
          if(bodyText.includes('verify you are human')){
            return 'Verification detected - complete it manually.';
          }

          const d = new Date();
          const date = String(d.getMonth()+1).padStart(2,'0') + '/' +
                       String(d.getDate()).padStart(2,'0') + '/' +
                       d.getFullYear();

          fillText('input[name="dpkDKgzq"]', window.yycConfig.date || date);

          await selectSite();
          await sleep(350);
          await dropdown('Business Unit',window.yycConfig.businessUnit,'Yaqm66vjv');
          await sleep(350);
          await dropdown('JLL BUSINESS LINE (RME or IFM)',window.yycConfig.businessLine,'PbXdbwMz1');

          fillText('input[name="nqoGJ90G"]',window.yycConfig.name);
          fillText('input[name="W0b1AEzN"]',window.yycConfig.email);
          fillText('input[name="31zAOmzP5"]',window.yycConfig.location);
          fillText('textarea[name="keo5JwEq"]',window.yycConfig.description);

          await dropdown('POTENTIAL OUTCOME',window.yycConfig.outcome,'jXkw32LwG');
          await sleep(350);
          await dropdown('Was STOP WORK Utilized?',window.yycConfig.stopWork,'5wRdn00Oa');
          await sleep(350);
          await dropdown('IMMEDIATE ACTION RESULT',window.yycConfig.actionResult,'YkOX0R7E');
          await sleep(350);
          await dropdown('LIKELIHOOD',window.yycConfig.likelihood,'1R2L5pXY');
          await sleep(350);
          await dropdown('SEVERITY',window.yycConfig.severity,'Ln0Ndyvd');

          const immediate = await waitFor(()=>labelledField('immediate action'));
          if(!setVal(immediate,window.yycConfig.immediateAction)) missing.push('Immediate Action');

          const receipt = await waitFor(()=> document.querySelector('[data-field-name="EMAIL_RECEIPT"] input[type="checkbox"]') ||
            [...document.querySelectorAll('input[type="checkbox"]')].find(el=>[el.getAttribute('aria-label'), ...(el.labels||[])].some(label=>
              /send me a copy of my responses/i.test(typeof label==='string'?label:label?.textContent||''))));
          if(!receipt) missing.push('Send me a copy of my responses');
          else {
            if(receipt.checked !== window.yycConfig.receipt) receipt.click();
            if(window.yycConfig.receipt) {
            const receiptEmail=await waitFor(()=>document.querySelector('[data-field-name="EMAIL_RECEIPT"] input[type="email"], [data-field-name="EMAIL_RECEIPT"] input[type="text"]') || labelledField('email address'));
            const mainEmail=document.querySelector('input[name="W0b1AEzN"]')?.value || window.yycConfig.email;
            if(!receipt.checked || !setVal(receiptEmail,mainEmail)) missing.push('Response-copy email');
            }
          }

          return (missing.length ? 'Check missing fields: '+missing.join(', ')+'. ' : '') + 'READY - review the form, attach current picture, complete verification if shown, and press Submit manually.';
        })();
 job.then(result=>{window.yycResult=result;}).catch(()=>{window.yycResult='Fill incomplete. Review the form manually.';}).finally(()=>{window.yycBusy=false;});
})();
