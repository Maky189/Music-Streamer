const API = window.API_BASE || '/api';
document.getElementById('api-url').textContent = API;

const $ = (sel) => document.querySelector(sel);
const fmtSecs = (s) => `${Math.floor(s/60)}:${String(s%60).padStart(2,'0')}`;

async function api(path, opts = {}) {
  const res = await fetch(API + path, {
    headers: { 'Content-Type': 'application/json' },
    ...opts,
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(body.error || `HTTP ${res.status}`);
  return body;
}

async function checkHealth() {
  const pill = $('#health');
  try {
    const r = await api('/health');
    pill.textContent = `DB OK · ${new Date(r.db_time).toLocaleTimeString()}`;
    pill.className = 'pill ok';
  } catch (e) {
    pill.textContent = `DB DOWN · ${e.message}`;
    pill.className = 'pill bad';
  }
}

async function loadStats() {
  const stats = await api('/stats');
  const labels = {
    users: 'Users', artists: 'Artists', albums: 'Albums', songs: 'Songs',
    playlists: 'Playlists', playlist_songs: 'Playlist songs', play_history: 'Plays',
  };
  $('#stats').innerHTML = Object.entries(stats).map(([k, v]) =>
    `<div class="stat"><div class="num">${v.toLocaleString()}</div>
     <div class="lbl">${labels[k] || k}</div></div>`).join('');
}

async function loadTopSongs() {
  const songs = await api('/songs/top?limit=16');
  $('#top-songs').innerHTML = songs.map(s =>
    `<li>
       <span>
         <button class="play-btn" data-song-id="${s.song_id}" data-title="${escape(s.title)} — ${escape(s.artist)}">▶</button>
         <strong>${escape(s.title)}</strong>
         <span class="secondary"> — ${escape(s.artist)}</span>
       </span>
       <span class="secondary">${Number(s.play_count).toLocaleString()} plays · ${fmtSecs(s.duration_seconds)}</span>
     </li>`).join('');
}

document.addEventListener('click', (e) => {
  const btn = e.target.closest('.play-btn');
  if (!btn) return;
  const songId = btn.dataset.songId;
  const title  = btn.dataset.title || `song ${songId}`;
  const audio  = $('#player');
  audio.src = `${API}/songs/${songId}/audio`;
  audio.play().catch(err => console.warn('playback failed:', err));
  $('#player-title').textContent = '▶ ' + title;
});

async function loadArtists() {
  const arts = await api('/artists');
  $('#artists').innerHTML = arts.slice(0, 10).map(a =>
    `<li><span><strong>${escape(a.name)}</strong>
       <span class="secondary"> · ${escape(a.genre)}</span></span>
       <span class="secondary">${Number(a.total_plays).toLocaleString()} plays</span></li>`).join('');
}

let searchTimer;
$('#q').addEventListener('input', (e) => {
  clearTimeout(searchTimer);
  const q = e.target.value;
  searchTimer = setTimeout(async () => {
    if (!q.trim()) { $('#search-results').innerHTML = ''; return; }
    try {
      const rows = await api('/songs/search?q=' + encodeURIComponent(q));
      $('#search-results').innerHTML = rows.map(s =>
        `<li>
           <span>
             <button class="play-btn" data-song-id="${s.song_id}" data-title="${escape(s.title)} — ${escape(s.artist)}">▶</button>
             ${escape(s.title)}<span class="secondary"> — ${escape(s.artist)}</span>
           </span>
           <span class="secondary">id ${s.song_id} · ${fmtSecs(s.duration_seconds)}</span>
         </li>`).join('') || '<li class="secondary">no matches</li>';
    } catch (err) {
      $('#search-results').innerHTML = `<li class="secondary">${err.message}</li>`;
    }
  }, 200);
});

async function loadPlaylists() {
  const pls = await api('/playlists');
  $('#playlist-pick').innerHTML = pls.map(p =>
    `<option value="${p.playlist_id}">${escape(p.name)} (by ${escape(p.owner)}, ${p.song_count} songs)</option>`).join('');
}

$('#playlist-load').addEventListener('click', async () => {
  const id = $('#playlist-pick').value;
  if (!id) return;
  try {
    const p = await api('/playlists/' + id);
    $('#playlist-detail').innerHTML = `
      <p><strong>${escape(p.name)}</strong> · owner ${escape(p.owner)} ·
         ${p.is_public ? 'public' : 'private'} · ${p.song_count} songs</p>
      <ol class="list">${p.songs.map(s =>
        `<li>
           <span>
             <button class="play-btn" data-song-id="${s.song_id}" data-title="${escape(s.title)} — ${escape(s.artist)}">▶</button>
             ${s.position}. ${escape(s.title)}<span class="secondary"> — ${escape(s.artist)}</span>
           </span>
           <span class="secondary">id ${s.song_id} · ${fmtSecs(s.duration_seconds)}</span>
         </li>`).join('')}</ol>`;
  } catch (e) {
    $('#playlist-detail').innerHTML = `<p class="msg bad">${e.message}</p>`;
  }
});

$('#add-song-btn').addEventListener('click', async () => {
  const playlistId = $('#playlist-pick').value;
  const songId = Number($('#add-song-id').value);
  const msg = $('#add-song-msg');
  msg.textContent = ''; msg.className = 'msg';
  if (!playlistId || !songId) {
    msg.textContent = 'pick a playlist and enter a song_id'; msg.classList.add('bad'); return;
  }
  try {
    const r = await api(`/playlists/${playlistId}/songs`, {
      method: 'POST', body: JSON.stringify({ song_id: songId }),
    });
    msg.textContent = `added at position ${r.position}`; msg.classList.add('ok');
    await loadPlaylists();
    $('#playlist-load').click();
    await loadStats();
  } catch (e) {
    msg.textContent = e.message; msg.classList.add('bad');
  }
});

$('#nu-btn').addEventListener('click', async () => {
  const msg = $('#nu-msg'); msg.textContent = ''; msg.className = 'msg';
  const body = {
    username:     $('#nu-username').value.trim(),
    email:        $('#nu-email').value.trim(),
    country:      $('#nu-country').value.trim().toUpperCase() || 'US',
    subscription: $('#nu-sub').value,
  };
  try {
    const u = await api('/users', { method: 'POST', body: JSON.stringify(body) });
    msg.textContent = `created user_id ${u.user_id}`; msg.classList.add('ok');
    await loadStats();
  } catch (e) { msg.textContent = e.message; msg.classList.add('bad'); }
});

$('#lp-btn').addEventListener('click', async () => {
  const msg = $('#lp-msg'); msg.textContent = ''; msg.className = 'msg';
  const body = {
    user_id:          Number($('#lp-user').value),
    song_id:          Number($('#lp-song').value),
    seconds_listened: Number($('#lp-seconds').value),
    completed:        $('#lp-completed').checked,
  };
  try {
    const r = await api('/plays', { method: 'POST', body: JSON.stringify(body) });
    msg.textContent = `logged play_id ${r.play_id}`; msg.classList.add('ok');
    if (body.completed) await loadTopSongs();
    await loadStats();
  } catch (e) { msg.textContent = e.message; msg.classList.add('bad'); }
});

function escape(s) {
  return String(s ?? '').replace(/[&<>"']/g, c => ({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
  }[c]));
}

(async function boot() {
  await checkHealth();
  setInterval(checkHealth, 15_000);
  try {
    await Promise.all([loadStats(), loadTopSongs(), loadArtists(), loadPlaylists()]);
  } catch (e) {
    console.error(e);
  }
})();
