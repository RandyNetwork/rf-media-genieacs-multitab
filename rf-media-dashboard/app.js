// RF MEDIA live dashboard client. Data is served by the local read-only bridge.
const $ = (s) => document.querySelector(s);
const fmt = (n) => new Intl.NumberFormat('id-ID').format(n || 0);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function setStat(i, value, note) {
  const card = document.querySelectorAll('.stat')[i];
  if (!card) return;
  card.querySelector('strong').textContent = fmt(value);
  card.querySelector('small').textContent = note;
}
async function loadDashboard() {
  const [summaryRes, devicesRes] = await Promise.all([
    fetch('/api/summary', {cache:'no-store'}),
    fetch('/api/devices?limit=12', {cache:'no-store'})
  ]);
  if (!summaryRes.ok || !devicesRes.ok) throw new Error('Backend API tidak tersedia');
  const summary = await summaryRes.json();
  const result = await devicesRes.json();
  setStat(0, summary.total, 'Total dari GenieACS');
  setStat(1, summary.online, 'Last Inform ≤ ' + summary.onlineWindowMinutes + ' menit');
  setStat(2, summary.offline, 'Last Inform > ' + summary.onlineWindowMinutes + ' menit');
  setStat(3, 0, 'Belum dihitung dari task queue');
  const stamp = $('.stamp');
  if (stamp) stamp.textContent = 'LIVE · ' + new Date(summary.generatedAt).toLocaleString('id-ID');
  const donut = $('.donut div');
  if (donut) donut.innerHTML = '<b>' + fmt(summary.total) + '</b><small>Perangkat</small>';
  const vendorList = $('.vendors ul');
  if (vendorList) {
    vendorList.innerHTML = summary.vendors.slice(0,6).map(v =>
      '<li><i class="c1"></i>' + esc(v.name) + '<b>' + fmt(v.count) + '</b></li>'
    ).join('');
  }
  const body = $('.tablepanel tbody');
  if (body) body.innerHTML = result.devices.map(d => {
    const date = d.lastInform ? new Date(d.lastInform).toLocaleString('id-ID') : '—';
    const status = d.online ? '<span class="pill online">Online</span>' : '<span class="pill neutral">Offline</span>';
    return '<tr><td>' + esc(date) + '</td><td>' + esc(d.serial || d.id) + '</td><td>' + esc(d.model) + '</td><td>—</td><td>' + status + '</td></tr>';
  }).join('') || '<tr><td colspan="5">Tidak ada perangkat.</td></tr>';
  const health = $('.health');
  if (health) health.innerHTML = '<b></b> NBI Connected <span>Update otomatis 30 detik</span><strong>RF MEDIA</strong>';
}
async function refresh() {
  try { await loadDashboard(); }
  catch (e) {
    const stamp = $('.stamp');
    if (stamp) stamp.textContent = 'BACKEND BELUM TERHUBUNG';
    const body = $('.tablepanel tbody');
    if (body) body.innerHTML = '<tr><td colspan="5">Gagal mengambil data. Periksa service backend RF MEDIA.</td></tr>';
    console.error(e);
  }
}
document.querySelectorAll('nav a').forEach(a => a.addEventListener('click', () => {
  document.querySelectorAll('nav a').forEach(n => n.classList.remove('active'));
  a.classList.add('active');
}));
refresh();
setInterval(refresh, 30000);
