// SuperTux Party in the player: loads the Godot web build (stp.js, stp.wasm) and
// the game package that fits this device from the engine directory into the
// player surface. stp.manifest.json (wasm/package.py) lists those files.
const canvas = document.querySelector('#canvas');
const status = document.querySelector('#status');
const loading = document.querySelector('#loading');
const loadingText = document.querySelector('#loading-text');
const surface = document.querySelector('#game-surface');
const startButton = document.querySelector('#start');
const fullscreenButton = document.querySelector('#fullscreen');
const closeButton = document.querySelector('#close');

const query = new URL(location.href).searchParams;
// Parameters that change what the page loads or runs only count on a local
// server, so a shared link cannot reach them on the public site.
const local = ['localhost', '127.0.0.1'].includes(location.hostname);
const devParam = name => local ? query.get(name) : null;
// ?engine= overrides the engine directory a deployment writes into the page.
const engineBase = new URL(devParam('engine') ||
  document.querySelector('meta[name="engine-base"]')?.content || './', location.href).href;
// The packages may live elsewhere, for example on a CDN that allows this site
// with CORS: <meta name="stp-data"> or ?data= names their directory.
const dataBase = new URL(devParam('data') ||
  document.querySelector('meta[name="stp-data"]')?.content || engineBase, location.href).href;

// The server this site offers in the game's server list: <meta name="stp-server">
// (read by common/scripts/web/web_platform.gd), or ?server= on a local server.
if (devParam('server')) {
  let meta = document.querySelector('meta[name="stp-server"]');
  if (!meta) {
    meta = document.createElement('meta');
    meta.name = 'stp-server';
    document.head.append(meta);
  }
  meta.content = devParam('server');
}

// Recent engine output, for diagnosing a failed start from the console. It also
// goes to the console as it happens, which keeps the context of a freeze visible.
const log = [];
window.stpLog = log;
function record(line, level = 'debug') {
  log.push(line);
  if (log.length > 2000) log.shift();
  console[level](line);
}

// On the site, messages follow the language the visitor chose. On the standalone
// page there is no dictionary and they stay in English.
const t = text => window.DemosI18n?.t(text) || text;

function showLoading(message) { loading.hidden = false; loadingText.textContent = message; }

function fail(message) {
  loading.hidden = true;
  status.textContent = `${t('Game error')}: ${message}. ${t('Reload the page to try again.')}`;
  window.applicationResult = { error: message };
  fullscreenButton.disabled = true;
}

// The engine draws what the canvas holds, so its pixels follow the size on screen.
// Phones report 2.5-4 device pixels per CSS pixel; each pixel costs frame time.
const touchScreen = navigator.maxTouchPoints > 0 && matchMedia('(pointer: coarse)').matches;
const pixelRatio = () => touchScreen ? Math.min(devicePixelRatio, 2) : devicePixelRatio;
new ResizeObserver(() => {
  canvas.width = Math.round(canvas.clientWidth * pixelRatio());
  canvas.height = Math.round(canvas.clientHeight * pixelRatio());
}).observe(canvas);
canvas.addEventListener('contextmenu', event => event.preventDefault());
canvas.addEventListener('pointerdown', () => canvas.focus());
window.applicationResult = null;

// Textures come in the compressed format of the GPU, so desktops and phones each
// download only what they can use. Asking the GPU is more reliable than the user
// agent: tablets and some laptops are on the other side of the obvious guess.
function devicePack(manifest) {
  // ?pack=mobile tries the other package on a local server.
  if (manifest.packs[devParam('pack')]) return manifest.packs[devParam('pack')];
  const gl = document.createElement('canvas').getContext('webgl2');
  const desktop = gl?.getExtension('WEBGL_compressed_texture_s3tc');
  gl?.getExtension('WEBGL_lose_context')?.loseContext();
  return desktop ? manifest.packs.desktop : manifest.packs.mobile;
}

// Keeps the large files in Cache Storage under their content hash, so a return
// visit starts without the network and a new build replaces them. Browsers may
// not offer it or may run out of quota: then the game loads as usual.
function cacheLargeFiles(manifest) {
  const hashes = new Map();
  for (const file of Object.values(manifest.files))
    hashes.set(new URL(file.name, file.pack ? dataBase : engineBase).href, file.hash);
  const networkFetch = window.fetch.bind(window);
  const cacheName = `stp-${manifest.version}`;
  window.fetch = async (input, init) => {
    const url = typeof input === 'string' ? new URL(input, location.href).href : input.url;
    if (!hashes.has(url) || !('caches' in window)) return networkFetch(input, init);
    let cache = null;
    try {
      cache = await caches.open(cacheName);
      const hit = await cache.match(url);
      if (hit) return hit;
    } catch (error) {
      record(`Cache Storage is not available: ${error}`);
    }
    const response = await networkFetch(input, init);
    if (cache && response.ok) {
      cache.put(url, response.clone()).catch(error => record(`Could not cache ${url}: ${error}`));
    }
    return response;
  };
  // Pages without HTTPS (a phone testing on the local network) have no Cache Storage.
  window.caches?.keys().then(names => names.filter(name => name.startsWith('stp-') && name !== cacheName)
    .forEach(name => caches.delete(name))).catch(() => {});
}

function loadScript(src) {
  return new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = src;
    script.onload = resolve;
    script.onerror = () => reject(new Error(`Could not load ${src}.`));
    document.body.append(script);
  });
}

const MiB = bytes => (bytes / 1048576).toFixed(0);

startButton.addEventListener('click', async () => {
  startButton.disabled = true;
  // Phones play in landscape fullscreen; needs this click, so it goes first. An
  // iPhone has no fullscreen for pages: there the surface just fills the window.
  if (touchScreen) {
    document.body.classList.add('playing');
    surface.requestFullscreen?.().then(() => screen.orientation?.lock?.('landscape')).catch(() => {});
  }
  surface.querySelector('.game-idle').hidden = true;
  showLoading(t('Preparing SuperTux Party…'));
  try {
    const manifestResponse = await fetch(new URL('stp.manifest.json', engineBase), { cache: 'no-cache' });
    if (!manifestResponse.ok) throw new Error(`stp.manifest.json: HTTP ${manifestResponse.status}`);
    const manifest = await manifestResponse.json();
    const pack = devicePack(manifest);
    cacheLargeFiles(manifest);
    await loadScript(new URL('stp.js', engineBase).href);
    const missing = window.Engine.getMissingFeatures({ threads: false });
    if (missing.length) throw new Error(`this browser cannot run the game: ${missing.join('; ')}`);

    const executable = new URL('stp', engineBase).href;
    const packURL = new URL(pack.name, dataBase).href;
    const engine = new window.Engine({
      canvas,
      executable,
      mainPack: packURL,
      // The page sizes the canvas (see the observer above) and stays in control of it.
      canvasResizePolicy: 0,
      focusCanvas: true,
      // The on-screen keyboard for the player name on phones.
      experimentalVK: true,
      fileSizes: { [`${executable}.wasm`]: manifest.files.wasm.size, [packURL]: pack.size },
      // The game starts in the language chosen on the site, until its own menu changes it.
      ...(window.DemosI18n ? { locale: document.documentElement.lang } : {}),
      // ?args= appends engine options, e.g. ?args=--verbose
      args: (devParam('args') || '').split(' ').filter(Boolean),
      onProgress: (current, total) => {
        if (total > 0) showLoading(`${t('Downloading the game')}: ${MiB(current)} / ${MiB(total)} MiB. ${t('Only the first start downloads it.')}`);
        else showLoading(t('Starting SuperTux Party…'));
      },
      onPrint: (...parts) => record(parts.join(' ')),
      onPrintError: (...parts) => record(parts.join(' '), 'warn'),
      // The engine cannot be restarted in place.
      onExit: () => location.reload(),
    });
    await engine.startGame();
    loading.hidden = true;
    status.textContent = t('SuperTux Party running.');
    fullscreenButton.disabled = false;
    closeButton.disabled = false;
    canvas.focus();
    window.applicationResult = null;
  } catch (error) {
    record(String(error?.stack || error), 'error');
    fail(error?.message || String(error));
  }
});

fullscreenButton.addEventListener('click', async () => {
  try {
    await surface.requestFullscreen();
    if (touchScreen) await screen.orientation?.lock?.('landscape').catch(() => {});
    canvas.focus();
  } catch (error) {
    status.textContent = `${t('Could not enter fullscreen')}: ${error.message}`;
  }
});

// The engine keeps the game's files saved on its own; a reload starts it over.
closeButton.addEventListener('click', () => location.reload());
