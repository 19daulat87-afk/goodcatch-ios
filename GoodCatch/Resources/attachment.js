(() => {
  let parts = null;
  const input = () => document.querySelector('input[type=file][data-client-id="file-uploader-input"]') || document.querySelector('input[type=file]');
  window.yycAttachment = {
    begin() { const f=input(); parts=null; if(!f || f.disabled)return false; parts=[]; return true; },
    chunk(encoded) { if(!parts)throw new Error('No attachment session'); const s=atob(encoded); parts.push(Uint8Array.from(s,c=>c.charCodeAt(0))); return true; },
    finish(metadata) {
      try {
        const f=input(); if(!f || f.disabled || !parts)return false;
        const file=new File(parts,metadata.name,{type:metadata.type,lastModified:Date.now()});
        if(!file.size)return false;
        const transfer=new DataTransfer(); transfer.items.add(file); f.files=transfer.files;
        f.dispatchEvent(new Event('input',{bubbles:true,composed:true}));
        f.dispatchEvent(new Event('change',{bubbles:true,composed:true}));
        return f.files.length===1 && f.files[0].size===file.size;
      } catch (_) { return false; } finally { parts=null; }
    }
  };
  return true;
})();
