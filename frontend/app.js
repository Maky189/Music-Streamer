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
  const pgPill = $('#health-pg');
  const mongoPill = $('#health-mongo');
  try {
    const r = await api('/health');
    if (r.pg && r.pg.ok) {
      pgPill.textContent = `PG OK \u00b7 ${new Date(r.pg.time).toLocaleTimeString()}`;
      pgPill.className = 'pill ok';
    } else {
      pgPill.textContent = 'PG DOWN';
      pgPill.className = 'pill bad';
    }
    if (r.mongo && r.mongo.ok) {
      mongoPill.textContent = 'MongoDB OK';
      mongoPill.className = 'pill mongo';
    } else {
      mongoPill.textContent = 'MongoDB DOWN';
      mongoPill.className = 'pill bad';
    }
  } catch (e) {
    pgPill.textContent = `PG DOWN \u00b7 ${e.message}`;
    pgPill.className = 'pill bad';
    mongoPill.textContent = 'MongoDB DOWN';
    mongoPill.className = 'pill bad';
  }
}

async function loadStats() {
  const stats = await api('/stats');
  const labels = {
    users: 'Users', artists: 'Artists', albums: 'Albums', songs: 'Songs',
    playlists: 'Playlists', playlist_songs: 'Playlist songs', play_history: 'Plays (PG)',
  };
  $('#stats').innerHTML = Object.entries(stats).map(([k, v]) =>
    `<div class="stat"><div class="num">${v.toLocaleString()}</div>
     <div class="lbl">${labels[k] || k}</div></div>`).join('');
}

async function loadMongoStats() {
  try {
    const stats = await api('/mongo/stats');
    const colData = stats.collections || {};
    const topSongs = stats.top_played_songs || [];
    const latest = stats.latest_play;
    let html = Object.entries(colData).map(([k, v]) =>
      `<div class="stat"><div class="num">${v.toLocaleString()}</div>
       <div class="lbl">${k}</div></div>`).join('');

    html += topSongs.slice(0, 3).map(s =>
      `<div class="stat"><div class="num" style="font-size:14px">${escape(s.title)}</div>
       <div class="lbl">${escape(s.artist)} \u00b7 ${s.plays} plays</div></div>`).join('');

    if (latest) {
      html += `<div class="stat"><div class="num" style="font-size:14px">${escape(latest.song_title || '')}</div>
       <div class="lbl">Latest \u00b7 ${escape(latest.artist || '')}</div></div>`;
    }

    $('#mongo-stats').innerHTML = html;
  } catch (e) {
    $('#mongo-stats').innerHTML = `<div class="stat"><div class="lbl">MongoDB stats unavailable</div></div>`;
  }
}

async function loadActivity() {
  try {
    const plays = await api('/mongo/recent-plays?limit=15');
    const list = $('#activity-list');
    if (!plays.length) {
      list.innerHTML = '<li class="secondary">No activity yet. Log a play!</li>';
      return;
    }
    list.innerHTML = plays.map(p =>
      `<li>
         <span>
           <button class="play-btn" data-song-id="${p.song_id || ''}" data-title="${escape(p.song_title || '')} — ${escape(p.artist_name || '')}">\u25b6</button>
           <strong>${escape(p.song_title || 'Unknown')}</strong>
           <span class="secondary"> \u2014 ${escape(p.artist_name || '')}</span>
         </span>
         <span class="secondary">${new Date(p.played_at).toLocaleTimeString()}</span>
       </li>`).join('');
  } catch (e) {
    $('#activity-list').innerHTML = `<li class="secondary">${e.message}</li>`;
  }
}

async function loadTopSongs() {
  const songs = await api('/songs/top?limit=16');
  $('#top-songs').innerHTML = songs.map(s =>
    `<li>
       <span>
         <button class="play-btn" data-song-id="${s.song_id}" data-title="${escape(s.title)} — ${escape(s.artist)}">\u25b6</button>
         <strong>${escape(s.title)}</strong>
         <span class="secondary"> — ${escape(s.artist)}</span>
       </span>
       <span class="secondary">${Number(s.play_count).toLocaleString()} plays \u00b7 ${fmtSecs(s.duration_seconds)}</span>
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
  $('#player-title').textContent = '\u25b6 ' + title;
});

async function loadArtists() {
  const arts = await api('/artists');
  $('#artists').innerHTML = arts.slice(0, 10).map(a =>
    `<li><span><strong>${escape(a.name)}</strong>
       <span class="secondary"> \u00b7 ${escape(a.genre)}</span></span>
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
             <button class="play-btn" data-song-id="${s.song_id}" data-title="${escape(s.title)} — ${escape(s.artist)}">\u25b6</button>
             ${escape(s.title)}<span class="secondary"> — ${escape(s.artist)}</span>
           </span>
           <span class="secondary">id ${s.song_id} \u00b7 ${fmtSecs(s.duration_seconds)}</span>
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
      <p><strong>${escape(p.name)}</strong> \u00b7 owner ${escape(p.owner)} \u00b7
         ${p.is_public ? 'public' : 'private'} \u00b7 ${p.song_count} songs</p>
      <ol class="list">${p.songs.map(s =>
        `<li>
           <span>
             <button class="play-btn" data-song-id="${s.song_id}" data-title="${escape(s.title)} — ${escape(s.artist)}">\u25b6</button>
             ${s.position}. ${escape(s.title)}<span class="secondary"> — ${escape(s.artist)}</span>
           </span>
           <span class="secondary">id ${s.song_id} \u00b7 ${fmtSecs(s.duration_seconds)}</span>
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
    msg.textContent = `logged play_id ${r.play_id} [PostgreSQL]`; msg.classList.add('ok');
    if (body.completed) await loadTopSongs();
    await loadStats();
  } catch (e) { msg.textContent = e.message; msg.classList.add('bad'); }
});

$('#lpm-btn').addEventListener('click', async () => {
  const msg = $('#lpm-msg'); msg.textContent = ''; msg.className = 'msg';
  const body = {
    user_id:          Number($('#lpm-user').value),
    song_id:          Number($('#lpm-song').value),
    seconds_listened: Number($('#lpm-seconds').value),
    completed:        $('#lpm-completed').checked,
  };
  try {
    const r = await api('/plays/mongo', { method: 'POST', body: JSON.stringify(body) });
    msg.textContent = `logged to MongoDB`; msg.classList.add('ok');
    await loadMongoStats();
    await loadActivity();
  } catch (e) { msg.textContent = e.message; msg.classList.add('bad'); }
});

$('#dw-btn').addEventListener('click', async () => {
  const msg = $('#dw-msg'); msg.textContent = ''; msg.className = 'msg';
  const body = {
    user_id:          Number($('#dw-user').value),
    song_id:          Number($('#dw-song').value),
    seconds_listened: Number($('#dw-seconds').value),
    completed:        $('#dw-completed').checked,
  };
  try {
    await api('/plays', { method: 'POST', body: JSON.stringify(body) });
    await api('/plays/mongo', { method: 'POST', body: JSON.stringify(body) });
    msg.textContent = 'logged to PostgreSQL (transactional) + MongoDB (analytics)';
    msg.classList.add('ok');
    await loadStats();
    await loadMongoStats();
    await loadActivity();
    if (body.completed) await loadTopSongs();
  } catch (e) { msg.textContent = e.message; msg.classList.add('bad'); }
});

$('#rec-load').addEventListener('click', async () => {
  const userId = Number($('#rec-user-id').value);
  const msg = $('#rec-msg');
  const list = $('#rec-list');
  msg.textContent = ''; msg.className = 'msg';
  if (!userId) { msg.textContent = 'enter a user_id'; msg.classList.add('bad'); return; }
  try {
    const recs = await api(`/recommendations/${userId}`);
    if (!recs.length) {
      list.innerHTML = '<li class="secondary">No recommendations yet. Click "Generate New".</li>';
      return;
    }
    const maxScore = Math.max(...recs.map(r => r.score));
    list.innerHTML = recs.map(r =>
      `<li>
         <span>
           <button class="play-btn" data-song-id="${r.song_id}" data-title="${escape(r.title || '')} — ${escape(r.artist || '')}">\u25b6</button>
           <strong>${escape(r.title || '')}</strong>
           <span class="secondary"> \u2014 ${escape(r.artist || '')}</span>
         </span>
         <span class="secondary">score ${Math.round(r.score * 100 / maxScore)}%</span>
       </li>`).join('');
  } catch (e) {
    list.innerHTML = `<li class="secondary">${e.message}</li>`;
  }
});

$('#rec-generate').addEventListener('click', async () => {
  const userId = Number($('#rec-user-id').value);
  const msg = $('#rec-msg');
  msg.textContent = 'generating...'; msg.className = 'msg';
  if (!userId) { msg.textContent = 'enter a user_id'; msg.classList.add('bad'); return; }
  try {
    await api(`/recommendations/generate/${userId}`, { method: 'POST' });
    msg.textContent = 'recommendations generated!'; msg.classList.add('ok');
    $('#rec-load').click();
    await loadMongoStats();
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
    await Promise.all([
      loadStats(),
      loadTopSongs(),
      loadArtists(),
      loadPlaylists(),
      loadMongoStats(),
      loadActivity(),
    ]);
  } catch (e) {
    console.error(e);
  }
})();
