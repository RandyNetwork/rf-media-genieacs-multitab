// RF MEDIA UI concept. Live GenieACS data integration is intentionally not enabled here.
document.querySelectorAll('nav a').forEach(a=>a.addEventListener('click',()=>{document.querySelectorAll('nav a').forEach(n=>n.classList.remove('active'));a.classList.add('active')}));
