/* UI de Sentinel Urbano. Consume la API real y el WebSocket; no inventa
   metricas ni acciones que el backend no expone. */
(function () {
  'use strict';

  var page = document.body.dataset.page || 'dashboard';
  var state = {
    ws: null,
    wsReconnect: 0,
    wsTimer: null,
    pingTimer: null,
    pingSent: null,
    latency: null,
    dashboard: { devices: [], alerts: [], recent: [], filter: 'all', summary: null },
    bitacora: {
      preset: '1h',
      desde: 0,
      hasta: 0,
      eventos: [],
      total: 0,
      severidad: 'todos',
      tipo: 'todos',
      busqueda: '',
      cargando: false,
      hashOk: null
    },
    nodo: { id: '', edificio: '' }
  };

  var SEV = {
    ok: {
      label: 'OK', icon: 'check_circle',
      header: 'bg-tertiary-container/30 text-tertiary',
      badge: 'bg-tertiary-container/20 text-tertiary',
      dot: 'bg-tertiary', text: 'text-tertiary'
    },
    alerta: {
      label: 'ALERTA', icon: 'warning',
      header: 'bg-secondary-container text-on-secondary-container',
      badge: 'bg-secondary-container text-secondary',
      dot: 'bg-secondary', text: 'text-secondary'
    },
    critico: {
      label: 'CRITICO', icon: 'crisis_alert',
      header: 'bg-error-container text-on-error',
      badge: 'bg-error-container text-on-error',
      dot: 'bg-error', text: 'text-error'
    },
    info: {
      label: 'ACTIVIDAD', icon: 'sensors',
      header: 'bg-surface-container-high text-primary',
      badge: 'bg-surface-container-highest text-primary',
      dot: 'bg-primary', text: 'text-primary'
    }
  };

  function $(sel, root) { return (root || document).querySelector(sel); }
  function $$(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }

  function esc(value) {
    return String(value == null ? '' : value).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  function fmtNumber(n) {
    try { return new Intl.NumberFormat('es-MX').format(Number(n) || 0); }
    catch (_e) { return String(n || 0); }
  }

  function toDate(value) {
    if (value == null) return null;
    if (value instanceof Date) return value;
    if (typeof value === 'number') return new Date(Math.floor(value / 1000));
    var d = new Date(value);
    return isNaN(d.getTime()) ? null : d;
  }

  function fmtTime(value, withMs) {
    var d = toDate(value);
    if (!d) return '--:--:--';
    var base = d.toLocaleTimeString('es-MX', { hour12: false });
    return withMs ? base + '.' + String(d.getMilliseconds()).padStart(3, '0') : base;
  }

  function fmtDateTime(value) {
    var d = toDate(value);
    if (!d) return '--';
    return d.toLocaleString('es-MX', { dateStyle: 'medium', timeStyle: 'medium' });
  }

  function localInputValue(micros) {
    var d = new Date(Math.floor(micros / 1000));
    if (isNaN(d.getTime())) return '';
    var pad = function (n) { return String(n).padStart(2, '0'); };
    return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) +
      'T' + pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds());
  }

  function fmtRelative(value) {
    var d = toDate(value);
    if (!d) return 'sin dato';
    var seg = Math.max(0, Math.round((Date.now() - d.getTime()) / 1000));
    if (seg < 5) return 'ahora';
    if (seg < 60) return 'hace ' + seg + ' s';
    var min = Math.floor(seg / 60);
    if (min < 60) return 'hace ' + min + ' min';
    var h = Math.floor(min / 60);
    if (h < 24) return 'hace ' + h + ' h';
    return 'hace ' + Math.floor(h / 24) + ' d';
  }

  function fmtOffset(segundos) {
    var s = Number(segundos) || 0;
    if (Math.abs(s) < 0.001) return '0 ms';
    return (s > 0 ? '+' : '') + (Math.abs(s) >= 1 ? s.toFixed(2) + ' s' : Math.round(s * 1000) + ' ms');
  }

  function microsNow() { return Date.now() * 1000; }

  function sumCounters(contadores) {
    if (!contadores || typeof contadores !== 'object') return 0;
    return Object.keys(contadores).reduce(function (acc, k) {
      return acc + (Number(contadores[k]) || 0);
    }, 0);
  }

  function tipoDispositivo(tipo) {
    return tipo === 'puerta' ? 'PUERTA' : tipo === 'camara' ? 'CAMARA' : String(tipo || '').toUpperCase();
  }

  function estadoDispositivo(estado) {
    if (estado === 'falla') return 'FALLA';
    if (estado === 'alerta') return 'ALERTA';
    return 'OK';
  }

  function severityOf(ev) {
    if (ev.tipo_evento === 'offline') return 'critico';
    if (ev.tipo_evento === 'alarma' || ev.desfasado) return 'alerta';
    if (ev.tipo_evento === 'online' || ev.tipo_evento === 'tarjeta_leida' || ev.tipo_evento === 'puerta_abierta') return 'ok';
    return 'info';
  }

  function eventMeta(ev) {
    var sev = severityOf(ev);
    var map = {
      offline: ['FALLA / SIN ENLACE', 'link_off'],
      online: ['NODO EN LINEA', 'wifi'],
      alarma: ['ALARMA OPERATIVA', 'warning'],
      movimiento: ['MOVIMIENTO DETECTADO', 'directions_run'],
      tarjeta_leida: ['ACCESO REGISTRADO', 'badge'],
      puerta_abierta: ['PUERTA ABIERTA', 'sensor_door']
    };
    var m = map[ev.tipo_evento] || ['EVENTO ' + String(ev.tipo_evento || '').toUpperCase(), 'sensors'];
    return { sev: sev, tone: SEV[sev], label: m[0], icon: m[1] };
  }

  function deviceTone(estado) {
    if (estado === 'falla') return SEV.critico;
    if (estado === 'alerta') return SEV.alerta;
    return SEV.ok;
  }

  function api(path, options) {
    options = options || {};
    return fetch(path, {
      method: options.method || 'GET',
      headers: Object.assign({ accept: 'application/json' }, options.headers || {}),
      body: options.body,
      cache: 'no-store'
    }).then(function (res) {
      return res.json().catch(function () { return null; }).then(function (body) {
        if (!res.ok) {
          var msg = body && body.error && body.error.mensaje ? body.error.mensaje : ('HTTP ' + res.status);
          var err = new Error(msg);
          err.status = res.status;
          err.body = body;
          throw err;
        }
        return body;
      });
    });
  }

  function toast(message, tone) {
    var el = $('#toast');
    if (!el) return;
    el.dataset.tone = tone || 'info';
    el.textContent = message;
    el.classList.remove('is-hidden');
    requestAnimationFrame(function () { el.classList.add('is-visible'); });
    clearTimeout(el._timer);
    el._timer = setTimeout(function () {
      el.classList.remove('is-visible');
      setTimeout(function () { el.classList.add('is-hidden'); }, 180);
    }, 4200);
  }

  function pageStatus(kind, message, retry) {
    var el = $('#page-status');
    if (!el) return;
    if (kind === 'hidden') {
      el.classList.add('is-hidden');
      el.innerHTML = '';
      return;
    }
    el.classList.remove('is-hidden');
    if (kind === 'loading') {
      el.className = 'mx-margin mb-space-md rounded-xl border border-outline-variant bg-surface-container px-space-md py-space-sm text-on-surface-variant fade-in';
      el.innerHTML = '<div class="flex items-center gap-2"><span class="material-symbols-outlined text-primary animate-spin text-[18px]">progress_activity</span><span class="font-mono-timestamp text-mono-timestamp">' + esc(message || 'Cargando telemetria...') + '</span></div>';
    } else {
      el.className = 'mx-margin mb-space-md rounded-xl border border-error/50 bg-error-container px-space-md py-space-sm text-on-error fade-in';
      el.innerHTML = '<div class="flex items-center justify-between gap-space-sm"><div class="flex items-center gap-2 min-w-0"><span class="material-symbols-outlined text-[18px]">error</span><span class="font-body-sm text-body-sm">' + esc(message || 'No fue posible consultar la API.') + '</span></div><button class="shrink-0 h-9 px-space-sm rounded-lg bg-surface-container-lowest/20 font-label-caps text-label-caps" id="retry-load" type="button">REINTENTAR</button></div>';
      var btn = $('#retry-load');
      if (btn) btn.addEventListener('click', retry || function () { location.reload(); });
    }
  }

  function setText(id, value) {
    var el = document.getElementById(id);
    if (el) el.textContent = value;
  }

  function setHtml(id, value) {
    var el = document.getElementById(id);
    if (el) el.innerHTML = value;
  }

  function wsSetState(text, tone) {
    var el = $('#ws-state');
    if (!el) return;
    el.textContent = text;
    el.className = 'font-mono-timestamp text-mono-timestamp ' + (tone || 'text-tertiary');
  }

  function wsSetLatency(ms) {
    var el = $('#ws-latency');
    if (el) el.textContent = ms == null ? '-- ms' : ms + ' ms';
  }

  function connectWS(handlers) {
    handlers = handlers || {};
    if (state.ws && state.ws.readyState <= 1) return;
    if (state.wsTimer) { clearTimeout(state.wsTimer); state.wsTimer = null; }
    var proto = location.protocol === 'https:' ? 'wss://' : 'ws://';
    var ws = new WebSocket(proto + location.host + '/ws/eventos');
    state.ws = ws;
    ws.onopen = function () {
      state.wsReconnect = 0;
      wsSetState('WS EN LINEA', 'text-tertiary');
      if (handlers.onOpen) handlers.onOpen();
      if (state.pingTimer) clearInterval(state.pingTimer);
      state.pingSent = Date.now();
      ws.send('ping');
      state.pingTimer = setInterval(function () {
        if (ws.readyState === 1) {
          state.pingSent = Date.now();
          ws.send('ping');
        }
      }, 10000);
    };
    ws.onmessage = function (msg) {
      var data;
      try { data = JSON.parse(msg.data); } catch (_e) { return; }
      if (data === 'pong') {
        if (state.pingSent) {
          state.latency = Date.now() - state.pingSent;
          wsSetLatency(state.latency);
        }
        return;
      }
      if (data && data.tipo === 'evento' && handlers.onEvent) handlers.onEvent(data.evento);
      if (data && data.tipo === 'resumen' && handlers.onSummary) handlers.onSummary(data);
    };
    ws.onerror = function () {
      wsSetState('WS CON ERROR', 'text-error');
    };
    ws.onclose = function () {
      if (state.pingTimer) { clearInterval(state.pingTimer); state.pingTimer = null; }
      wsSetState('RECONECTANDO', 'text-secondary');
      if (state.ws === ws) state.ws = null;
      var delay = Math.min(10000, 1000 * Math.pow(2, Math.min(state.wsReconnect, 3)));
      state.wsReconnect += 1;
      state.wsTimer = setTimeout(function () { connectWS(handlers); }, delay);
    };
  }

  function disconnectWS() {
    if (state.wsTimer) clearTimeout(state.wsTimer);
    if (state.pingTimer) clearInterval(state.pingTimer);
    if (state.ws) { try { state.ws.close(); } catch (_e) {} }
  }

  function refreshAlertsBadge() {
    return api('/api/alertas').then(function (data) {
      var n = data.total || 0;
      setText('alert-badge', String(n));
      var badge = $('#alert-badge');
      if (badge) badge.classList.toggle('is-hidden', n === 0);
    }).catch(function () {});
  }

  /* ------------------------------------------------------------------ */
  /* Dashboard                                                          */
  /* ------------------------------------------------------------------ */

  function dashboardStats(devices) {
    var total = devices.length;
    var ok = devices.filter(function (d) { return d.estado === 'ok'; }).length;
    var alerta = devices.filter(function (d) { return d.estado === 'alerta'; }).length;
    var falla = devices.filter(function (d) { return d.estado === 'falla'; }).length;
    var camaras = devices.filter(function (d) { return d.tipo === 'camara'; }).length;
    var puertas = devices.filter(function (d) { return d.tipo === 'puerta'; }).length;
    return { total: total, ok: ok, alerta: alerta, falla: falla, camaras: camaras, puertas: puertas };
  }

  function renderDashboardKpis(devices, salud) {
    var s = dashboardStats(devices);
    var pct = s.total ? ((s.ok / s.total) * 100).toFixed(1) : '0.0';
    setText('system-pct', 'SISTEMA OPERATIVO ' + pct + '%');
    setText('system-seq', 'SEQ ' + (salud && salud.bitacora ? salud.bitacora.seq : 0));
    setText('kpi-ok', fmtNumber(s.ok));
    setText('kpi-ok-sub', fmtNumber(s.camaras) + ' camaras / ' + fmtNumber(s.puertas) + ' puertas');
    setText('kpi-alert', String(s.alerta).padStart(2, '0'));
    setText('kpi-alert-sub', s.alerta ? 'nodos con advertencia' : 'sin advertencias activas');
    setText('kpi-fail', String(s.falla).padStart(2, '0'));
    setText('kpi-fail-sub', s.falla ? 'nodos desconectados' : 'sin nodos desconectados');
    setText('pill-all-count', fmtNumber(s.total));
    setText('pill-alert-count', fmtNumber(s.alerta));
    setText('pill-access-count', fmtNumber(s.puertas));
    setText('pill-cams-count', fmtNumber(s.camaras));

    var failIds = devices.filter(function (d) { return d.estado === 'falla'; }).map(function (d) { return d.id; });
    setText('kpi-fail-detail', failIds.length ? failIds.slice(0, 3).join(' / ') : 'Enlace de telemetria estable');
    var alertIds = devices.filter(function (d) { return d.estado === 'alerta'; }).map(function (d) { return d.id; });
    setText('kpi-alert-detail', alertIds.length ? alertIds.slice(0, 3).join(' / ') : 'Sin eventos de alarma recientes');
  }

  function videoPlaceholder(dev, tone) {
    var icon = dev.estado === 'falla' ? 'videocam_off' : 'videocam';
    var title = dev.estado === 'falla' ? 'SIN ENLACE DE TELEMETRIA' : 'TELEMETRIA DEL NODO';
    var stateLabel = dev.estado === 'falla' ? 'OFFLINE' : (dev.estado === 'alerta' ? 'ALERTA' : 'EN LINEA');
    return '' +
      '<div class="relative w-full aspect-video bg-surface-container-lowest overflow-hidden">' +
        '<div class="absolute inset-0 bg-[radial-gradient(circle_at_center,rgba(14,165,233,0.18)_0%,transparent_58%)]"></div>' +
        '<svg class="absolute inset-0 w-full h-full text-primary/30" fill="none" stroke="currentColor" stroke-width="0.6" viewBox="0 0 320 180">' +
          '<circle cx="160" cy="90" r="42" stroke-dasharray="2 4"></circle>' +
          '<circle cx="160" cy="90" r="78" stroke-dasharray="1 7"></circle>' +
          '<line x1="40" x2="280" y1="90" y2="90" stroke-dasharray="1 5"></line>' +
          '<line x1="160" x2="160" y1="18" y2="162" stroke-dasharray="1 5"></line>' +
        '</svg>' +
        '<div class="absolute inset-0 flex flex-col items-center justify-center gap-space-xs">' +
          '<div class="w-12 h-12 rounded-full ' + (dev.estado === 'falla' ? 'bg-error-container text-on-error' : 'bg-surface-container-high ' + tone.text) + ' flex items-center justify-center">' +
            '<span class="material-symbols-outlined text-[26px]">' + icon + '</span>' +
          '</div>' +
          '<span class="font-mono-timestamp text-mono-timestamp font-bold uppercase tracking-widest ' + tone.text + '">' + esc(title) + '</span>' +
          '<span class="font-body-sm text-body-sm text-on-surface-variant">Sin video RTSP; solo telemetria del nodo</span>' +
        '</div>' +
        '<div class="absolute top-2 left-2 right-2 flex items-center justify-between">' +
          '<div class="flex items-center gap-1.5 bg-surface-container-lowest/80 backdrop-blur-md px-2 py-1 rounded">' +
            '<span class="relative flex h-2 w-2"><span class="animate-ping absolute inline-flex h-full w-full rounded-full ' + tone.dot + ' opacity-75"></span><span class="relative inline-flex rounded-full h-2 w-2 ' + tone.dot + '"></span></span>' +
            '<span class="font-label-caps text-label-caps ' + tone.text + ' font-bold tracking-wider">' + stateLabel + '</span>' +
          '</div>' +
          '<div class="bg-surface-container-lowest/80 backdrop-blur-md px-2 py-1 rounded font-mono-timestamp text-mono-timestamp text-on-surface">' + esc(dev.id) + '</div>' +
        '</div>' +
        '<div class="absolute bottom-2 left-2 right-2 flex items-center justify-between text-on-surface font-mono-timestamp text-mono-timestamp">' +
          '<div class="bg-surface-container-lowest/80 backdrop-blur-md px-2 py-0.5 rounded flex items-center gap-1">' +
            '<span class="' + tone.text + '">' + esc(dev.edificio) + '</span>' +
            '<span class="text-on-surface-variant">|</span>' +
            '<span class="' + tone.text + '">' + fmtOffset(dev.offset_segundos) + ' offset</span>' +
          '</div>' +
          '<span class="bg-surface-container-lowest/80 backdrop-blur-md px-2 py-0.5 rounded">HASH ' + (dev.recientes && dev.recientes[0] ? esc(shortHash(dev.recientes[0].hash)) : '--') + '</span>' +
        '</div>' +
      '</div>';
  }

  function shortHash(hash) {
    if (!hash) return '--';
    var s = String(hash);
    return s.length > 12 ? s.slice(0, 8) + '...' + s.slice(-4) : s;
  }

  function renderDeviceCard(dev) {
    var tone = deviceTone(dev.estado);
    var last = dev.recientes && dev.recientes[0];
    var total = sumCounters(dev.contadores);
    var detailHref = 'nodo.html?id=' + encodeURIComponent(dev.id) + '&edificio=' + encodeURIComponent(dev.edificio);
    var meta = '<div class="p-space-md flex flex-col gap-space-xs">' +
      '<div class="flex items-start justify-between gap-space-sm">' +
        '<div class="flex flex-col min-w-0">' +
          '<div class="flex items-center gap-space-xs min-w-0">' +
            '<a class="font-headline-sm text-headline-sm text-on-surface font-semibold truncate hover:text-primary" href="' + detailHref + '">' + esc(dev.id) + '</a>' +
            '<span class="bg-surface-container-high ' + tone.text + ' font-mono-timestamp text-mono-timestamp px-1.5 py-0.5 rounded font-bold shrink-0">' + esc(tipoDispositivo(dev.tipo)) + '</span>' +
          '</div>' +
          '<span class="font-body-sm text-body-sm text-on-surface-variant truncate">' + esc(dev.edificio) + ' • ' + esc(estadoDispositivo(dev.estado)) + '</span>' +
        '</div>' +
        '<a class="w-11 h-11 bg-surface-container-high hover:bg-surface-bright ' + tone.text + ' rounded-lg flex items-center justify-center flex-shrink-0" href="' + detailHref + '" title="Abrir detalle del nodo">' +
          '<span class="material-symbols-outlined text-[20px]">open_in_new</span>' +
        '</a>' +
      '</div>' +
      '<div class="grid grid-cols-3 gap-space-xs pt-space-xs mt-space-xs bg-surface-container-lowest/40 p-space-xs rounded-lg text-center">' +
        telemetryCell('EVENTOS', fmtNumber(total), 'text-on-surface') +
        telemetryCell('LATIDO', fmtRelative(dev.ultimo_latido_iso), tone.text) +
        telemetryCell('OFFSET', fmtOffset(dev.offset_segundos), Math.abs(Number(dev.offset_segundos) || 0) > 1 ? 'text-secondary' : 'text-tertiary') +
      '</div>' +
      (last ? '<p class="font-body-sm text-body-sm text-on-surface-variant truncate pt-space-xs">Ultimo: ' + esc(last.tipo_evento) + ' • ' + esc(fmtTime(last.ts_corregido_iso, true)) + '</p>' : '') +
    '</div>';

    if (dev.tipo === 'camara' || dev.estado === 'falla') {
      return '<article class="bg-surface-container-low rounded-xl overflow-hidden shadow-sm flex flex-col fade-in">' + videoPlaceholder(dev, tone) + meta + '</article>';
    }

    return '<article class="bg-surface-container-low rounded-xl p-space-md shadow-sm flex flex-col gap-space-sm fade-in">' +
      '<div class="flex items-start justify-between gap-space-sm">' +
        '<div class="flex items-center gap-space-sm min-w-0">' +
          '<div class="w-11 h-11 rounded-lg ' + (dev.estado === 'alerta' ? 'bg-secondary-container text-primary' : 'bg-surface-container-high ' + tone.text) + ' flex items-center justify-center flex-shrink-0">' +
            '<span class="material-symbols-outlined text-[24px]">sensor_door</span>' +
          '</div>' +
          '<div class="flex flex-col min-w-0">' +
            '<div class="flex items-center gap-space-xs min-w-0">' +
              '<a class="font-headline-sm text-headline-sm text-on-surface font-semibold truncate hover:text-primary" href="' + detailHref + '">' + esc(dev.id) + '</a>' +
              '<span class="font-mono-timestamp text-mono-timestamp bg-surface-container-high ' + tone.text + ' px-1.5 py-0.5 rounded font-bold shrink-0">' + esc(tipoDispositivo(dev.tipo)) + '</span>' +
            '</div>' +
            '<span class="font-body-sm text-body-sm text-on-surface-variant truncate">' + esc(dev.edificio) + ' • Ultimo latido ' + esc(fmtRelative(dev.ultimo_latido_iso)) + '</span>' +
          '</div>' +
        '</div>' +
        '<span class="bg-surface-container-high ' + tone.text + ' font-mono-timestamp text-mono-timestamp px-2 py-1 rounded font-bold whitespace-nowrap">' + esc(estadoDispositivo(dev.estado)) + '</span>' +
      '</div>' +
      '<div class="bg-surface-container-high p-space-sm rounded-lg flex flex-col gap-space-xs">' +
        '<div class="flex items-center gap-1.5 ' + tone.text + '">' +
          '<span class="material-symbols-outlined text-[18px]">' + (dev.estado === 'falla' ? 'link_off' : 'lock_open') + '</span>' +
          '<span class="font-label-caps text-label-caps font-bold uppercase tracking-wider">' + (last ? esc(last.tipo_evento) : 'SIN EVENTOS RECIENTES') + '</span>' +
        '</div>' +
        '<p class="font-body-sm text-body-sm text-on-surface-variant">' + (last ? 'Evento ' + esc(last.tipo_evento) + ' recibido ' + esc(fmtRelative(last.ts_recepcion_iso)) + (last.persona ? ' • Persona: ' + esc(last.persona) : '') : 'El nodo aun no reporta eventos en esta sesion.') + '</p>' +
      '</div>' +
      '<div class="grid grid-cols-2 gap-space-xs pt-1">' +
        '<a class="h-12 bg-primary text-on-primary hover:bg-primary-container font-headline-sm text-headline-sm font-bold rounded-lg flex items-center justify-center gap-2 shadow-sm transition-transform active:scale-95" href="' + detailHref + '">' +
          '<span class="material-symbols-outlined text-[20px]">monitor_heart</span><span>VER NODO</span>' +
        '</a>' +
        '<a class="h-12 bg-surface-container-high hover:bg-surface-bright text-on-surface rounded-lg flex items-center justify-center gap-2 font-headline-sm text-headline-sm" href="bitacora.html?dispositivo=' + encodeURIComponent(dev.id) + '">' +
          '<span class="material-symbols-outlined text-[20px]">history</span><span>BITACORA</span>' +
        '</a>' +
      '</div>' +
    '</article>';
  }

  function telemetryCell(label, value, tone) {
    return '<div class="flex flex-col min-w-0"><span class="font-label-caps text-label-caps text-on-surface-variant uppercase truncate">' + esc(label) + '</span><span class="font-mono-timestamp text-mono-timestamp ' + tone + ' font-bold truncate">' + esc(value) + '</span></div>';
  }

  function renderDashboardNodes() {
    var cont = $('#dashboard-nodes');
    if (!cont) return;
    var devs = state.dashboard.devices.slice();
    var filter = state.dashboard.filter;
    if (filter === 'alert') devs = devs.filter(function (d) { return d.estado === 'alerta'; });
    if (filter === 'access') devs = devs.filter(function (d) { return d.tipo === 'puerta'; });
    if (filter === 'cams') devs = devs.filter(function (d) { return d.tipo === 'camara'; });
    var priority = { falla: 0, alerta: 1, ok: 2 };
    devs.sort(function (a, b) { return (priority[a.estado] || 3) - (priority[b.estado] || 3); });
    if (!devs.length) {
      cont.innerHTML = '<div class="bg-surface-container-low rounded-xl p-space-lg text-center text-on-surface-variant font-body-sm text-body-sm">No hay nodos para este filtro.</div>';
      return;
    }
    cont.innerHTML = devs.slice(0, 4).map(renderDeviceCard).join('');
  }

  function renderRecentEvents(events) {
    var cont = $('#dashboard-recent');
    if (!cont) return;
    if (!events || !events.length) {
      cont.innerHTML = '<div class="bg-surface-container-low rounded-lg p-space-md text-center text-on-surface-variant font-body-sm text-body-sm">Sin eventos en la ultima hora.</div>';
      return;
    }
    cont.innerHTML = events.slice(0, 5).map(function (ev) {
      var meta = eventMeta(ev);
      return '<a class="bg-surface-container p-space-sm rounded-lg flex items-center justify-between gap-space-sm hover:bg-surface-container-high transition-colors fade-in" href="bitacora.html?dispositivo=' + encodeURIComponent(ev.dispositivo_id) + '">' +
        '<div class="flex items-center gap-space-sm min-w-0">' +
          '<div class="w-8 h-8 rounded-full ' + (meta.sev === 'critico' ? 'bg-error-container' : meta.sev === 'alerta' ? 'bg-secondary-container' : 'bg-surface-container-high') + ' flex items-center justify-center flex-shrink-0">' +
            '<span class="material-symbols-outlined text-[16px] ' + meta.tone.text + '">' + meta.icon + '</span>' +
          '</div>' +
          '<div class="flex flex-col min-w-0">' +
            '<div class="flex items-center gap-space-xs min-w-0">' +
              '<span class="font-body-md text-body-md text-on-surface font-medium truncate">' + esc(ev.tipo_evento) + ' • ' + esc(ev.dispositivo_id) + '</span>' +
              '<span class="font-label-caps text-label-caps ' + meta.tone.text + ' uppercase shrink-0">' + meta.tone.label + '</span>' +
            '</div>' +
            '<span class="font-mono-timestamp text-mono-timestamp text-on-surface-variant truncate">' + esc(ev.edificio) + (ev.persona ? ' • ' + esc(ev.persona) : '') + '</span>' +
          '</div>' +
        '</div>' +
        '<span class="font-mono-timestamp text-mono-timestamp ' + (meta.sev === 'critico' ? 'text-error' : 'text-on-surface-variant') + ' flex-shrink-0">' + esc(fmtTime(ev.ts_corregido_iso, false)) + '</span>' +
      '</a>';
    }).join('');
  }

  function initDashboard() {
    $$('.node-filter').forEach(function (btn) {
      btn.addEventListener('click', function () {
        state.dashboard.filter = btn.dataset.filter || 'all';
        $$('.node-filter').forEach(function (b) {
          var active = b === btn;
          b.classList.toggle('bg-primary-container', active);
          b.classList.toggle('text-on-primary', active);
          b.classList.toggle('bg-surface-container-high', !active);
          b.classList.toggle('text-on-surface', !active);
        });
        renderDashboardNodes();
      });
    });
    var camsNav = $('[data-nav-cams]');
    if (camsNav) {
      camsNav.addEventListener('click', function (e) {
        e.preventDefault();
        state.dashboard.filter = 'cams';
        var btn = $('.node-filter[data-filter="cams"]');
        if (btn) btn.click();
        var target = $('#nodos');
        if (target) target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      });
    }

    pageStatus('loading', 'Consultando dispositivos, bitacora y salud del nodo...');
    Promise.all([
      api('/api/salud'),
      api('/api/dispositivos'),
      api('/api/eventos?desde=' + (microsNow() - 3600 * 1000000) + '&hasta=' + microsNow() + '&limite=5')
    ]).then(function (res) {
      var salud = res[0];
      var devices = res[1].dispositivos || [];
      var eventos = res[2].eventos || [];
      state.dashboard.devices = devices;
      state.dashboard.recent = eventos;
      renderDashboardKpis(devices, salud);
      renderDashboardNodes();
      renderRecentEvents(eventos);
      setText('last-update', 'Actualizado ' + fmtTime(new Date(), false));
      pageStatus('hidden');
      refreshAlertsBadge();
    }).catch(function (err) {
      pageStatus('error', 'No se pudo cargar el dashboard: ' + err.message, initDashboard);
    });

    connectWS({
      onEvent: function (ev) {
        state.dashboard.recent = [ev].concat(state.dashboard.recent).slice(0, 5);
        renderRecentEvents(state.dashboard.recent);
        setText('last-update', 'Evento en vivo ' + fmtTime(ev.ts_corregido_iso, false));
      },
      onSummary: function (s) {
        state.dashboard.summary = s;
        var devices = state.dashboard.devices;
        if (devices.length) {
          var s0 = dashboardStats(devices);
          s0.total = s.dispositivos;
          s0.alerta = s.en_alerta;
          s0.falla = s.camaras_offline + s.puertas_offline;
          s0.ok = Math.max(0, s0.total - s0.alerta - s0.falla);
          setText('kpi-ok', fmtNumber(s0.ok));
          setText('kpi-alert', String(s0.alerta).padStart(2, '0'));
          setText('kpi-fail', String(s0.falla).padStart(2, '0'));
          var pct = s0.total ? ((s0.ok / s0.total) * 100).toFixed(1) : '0.0';
          setText('system-pct', 'SISTEMA OPERATIVO ' + pct + '%');
          setText('system-seq', 'SEQ ' + s.seq);
        }
      }
    });
    setInterval(function () { refreshAlertsBadge(); }, 30000);
  }

  /* ------------------------------------------------------------------ */
  /* Bitacora                                                           */
  /* ------------------------------------------------------------------ */

  function presetRange(preset) {
    var hasta = microsNow();
    var desde = hasta;
    if (preset === '15m') desde = hasta - 15 * 60 * 1000000;
    else if (preset === '1h') desde = hasta - 3600 * 1000000;
    else if (preset === '8h') desde = hasta - 8 * 3600 * 1000000;
    else if (preset === 'hoy') {
      var d = new Date();
      d.setHours(0, 0, 0, 0);
      desde = d.getTime() * 1000;
    }
    return { desde: desde, hasta: hasta };
  }

  function setPreset(preset) {
    state.bitacora.preset = preset;
    var r = presetRange(preset);
    state.bitacora.desde = r.desde;
    state.bitacora.hasta = r.hasta;
    updateRangeLabel();
    $$('.preset-pill[data-preset]').forEach(function (b) {
      var active = b.dataset.preset === preset;
      b.classList.toggle('bg-primary-container', active);
      b.classList.toggle('text-on-primary', active);
      b.classList.toggle('font-bold', active);
      b.classList.toggle('shadow-sm', active);
      b.classList.toggle('bg-surface-container', !active);
      b.classList.toggle('text-on-surface-variant', !active);
    });
  }

  function updateRangeLabel() {
    var b = state.bitacora;
    setText('range-label', fmtDateTime(b.desde) + '  -  ' + fmtDateTime(b.hasta));
  }

  function matchSearch(ev, q) {
    if (!q) return true;
    var s = (ev.dispositivo_id + ' ' + ev.edificio + ' ' + ev.tipo_evento + ' ' + (ev.persona || '') + ' ' + (ev.hash || '')).toLowerCase();
    return s.indexOf(q.toLowerCase()) !== -1;
  }

  function matchSeverity(ev, sev) {
    if (sev === 'todos') return true;
    return severityOf(ev) === sev;
  }

  function matchTipo(ev, tipo) {
    if (tipo === 'todos') return true;
    if (tipo === 'fallos') return ev.tipo_evento === 'offline';
    return ev.tipo_dispositivo === tipo;
  }

  function filteredEvents() {
    var b = state.bitacora;
    return b.eventos.filter(function (ev) {
      return matchSearch(ev, b.busqueda) && matchSeverity(ev, b.severidad) && matchTipo(ev, b.tipo);
    });
  }

  function renderBitacora() {
    var b = state.bitacora;
    var cont = $('#bitacora-events');
    if (!cont) return;
    var events = filteredEvents();
    b.filtrados = events;
    var counts = { ok: 0, alerta: 0, critico: 0, info: 0 };
    b.eventos.forEach(function (ev) { counts[severityOf(ev)] += 1; });
    setText('sev-all-count', fmtNumber(b.eventos.length));
    setText('sev-ok-count', fmtNumber(counts.ok));
    setText('sev-alert-count', fmtNumber(counts.alerta));
    setText('sev-crit-count', fmtNumber(counts.critico));
    setText('footer-count', 'Mostrando ' + fmtNumber(Math.min(events.length, 80)) + ' de ' + fmtNumber(events.length) + ' eventos filtrados (total recibido: ' + fmtNumber(b.total) + ')');
    if (!events.length) {
      cont.innerHTML = '<div class="bg-surface-container rounded-xl p-space-lg text-center text-on-surface-variant font-body-sm text-body-sm">No hay eventos que coincidan con los filtros y el rango seleccionado.</div>';
      return;
    }
    cont.innerHTML = events.slice(0, 80).map(renderEventCard).join('');
    $$('[data-copiar-hash]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var hash = btn.dataset.copiarHash || '';
        copyText(hash).then(function () { toast('Hash copiado: ' + shortHash(hash), 'info'); })
          .catch(function () { toast('No se pudo copiar el hash.', 'error'); });
      });
    });
  }

  function renderEventCard(ev) {
    var meta = eventMeta(ev);
    var detail = 'nodo.html?id=' + encodeURIComponent(ev.dispositivo_id) + '&edificio=' + encodeURIComponent(ev.edificio);
    var desc = 'Evento ' + ev.tipo_evento + ' recibido en ' + ev.edificio + '.';
    if (ev.persona) desc += ' Persona / credencial: ' + ev.persona + '.';
    if (ev.desfasado) desc += ' Reloj desfasado ' + fmtOffset(ev.offset_reloj / 1000000) + '.';
    return '<article class="flex flex-col bg-surface-container rounded-xl overflow-hidden shadow-md fade-in">' +
      '<div class="flex items-center justify-between px-space-md py-space-sm ' + meta.tone.header + '">' +
        '<div class="flex items-center gap-2 min-w-0">' +
          '<span class="material-symbols-outlined text-[18px]">' + meta.icon + '</span>' +
          '<span class="font-label-caps text-label-caps font-bold truncate">' + esc(meta.label) + '</span>' +
        '</div>' +
        '<span class="font-mono-timestamp text-mono-timestamp font-bold flex-shrink-0">' + esc(fmtTime(ev.ts_corregido_iso, true)) + '</span>' +
      '</div>' +
      '<div class="p-space-md flex flex-col gap-space-sm">' +
        '<div class="flex items-start justify-between gap-space-sm">' +
          '<div class="flex flex-col min-w-0">' +
            '<a class="font-headline-sm text-headline-sm text-on-surface font-semibold truncate hover:text-primary" href="' + detail + '">' + esc(ev.dispositivo_id) + '</a>' +
            '<span class="font-body-sm text-body-sm text-on-surface-variant truncate">' + esc(ev.edificio) + ' • ' + esc(tipoDispositivo(ev.tipo_dispositivo)) + '</span>' +
          '</div>' +
          '<span class="px-2 py-0.5 rounded bg-surface-container-high ' + meta.tone.text + ' font-mono-timestamp text-mono-timestamp flex-shrink-0">SEQ ' + esc(ev.seq) + '</span>' +
        '</div>' +
        '<p class="font-body-md text-body-md text-on-surface bg-surface-container-lowest p-space-sm rounded-lg leading-relaxed">' + esc(desc) + '</p>' +
        (ev.persona ? '<div class="flex items-center gap-space-sm bg-surface-container-lowest p-space-sm rounded-lg"><span class="material-symbols-outlined text-[18px] text-primary">badge</span><span class="font-mono-code text-mono-code text-on-surface">' + esc(ev.persona) + '</span></div>' : '') +
        '<div class="flex items-center justify-between text-on-surface-variant pt-1 gap-space-sm">' +
          '<div class="flex items-center gap-1.5 min-w-0">' +
            '<span class="material-symbols-outlined text-tertiary text-[16px]">verified</span>' +
            '<span class="font-mono-timestamp text-mono-timestamp text-tertiary truncate">HASH: ' + esc(shortHash(ev.hash)) + '</span>' +
          '</div>' +
          '<span class="font-mono-timestamp text-mono-timestamp shrink-0">' + esc(fmtRelative(ev.ts_recepcion_iso)) + '</span>' +
        '</div>' +
        '<div class="grid grid-cols-2 gap-space-sm pt-space-xs">' +
          '<a class="h-11 flex items-center justify-center gap-1.5 px-space-sm rounded-lg bg-surface-container-high text-on-surface font-headline-sm text-headline-sm hover:bg-surface-bright active:scale-[0.98] transition-all" href="' + detail + '">' +
            '<span class="material-symbols-outlined text-[18px]">open_in_new</span><span>Ver nodo</span>' +
          '</a>' +
          '<button class="h-11 flex items-center justify-center gap-1.5 px-space-sm rounded-lg bg-primary-container text-on-primary font-headline-sm text-headline-sm font-semibold active:scale-[0.98] transition-all shadow-sm" data-copiar-hash="' + esc(ev.hash) + '" type="button">' +
            '<span class="material-symbols-outlined text-[18px]">content_copy</span><span>Copiar hash</span>' +
          '</button>' +
        '</div>' +
      '</div>' +
    '</article>';
  }

  function cargarBitacora() {
    var b = state.bitacora;
    if (b.cargando) return;
    b.cargando = true;
    pageStatus('loading', 'Consultando bitacora en el rango seleccionado...');
    var url = '/api/eventos?desde=' + b.desde + '&hasta=' + b.hasta + '&limite=1000';
    api(url).then(function (data) {
      b.eventos = data.eventos || [];
      b.total = data.total || 0;
      b.desde = data.desde || b.desde;
      b.hasta = data.hasta || b.hasta;
      updateRangeLabel();
      renderBitacora();
      pageStatus('hidden');
      b.cargando = false;
    }).catch(function (err) {
      b.cargando = false;
      pageStatus('error', 'No se pudo consultar la bitacora: ' + err.message, cargarBitacora);
    });
    api('/api/bitacora/verificar').then(function (data) {
      b.hashOk = data.integridad === 'ok';
      var el = $('#hash-status');
      if (el) {
        el.textContent = b.hashOk ? 'SHA-256 OK' : 'CADENA ALTERADA';
        el.className = 'font-mono-timestamp text-mono-timestamp ' + (b.hashOk ? 'text-tertiary' : 'text-error');
      }
    }).catch(function (err) {
      b.hashOk = false;
      var el = $('#hash-status');
      if (el) {
        el.textContent = err.status === 409 ? 'CADENA ALTERADA' : 'SIN VERIFICAR';
        el.className = 'font-mono-timestamp text-mono-timestamp text-error';
      }
    });
  }

  function csvEscape(v) {
    var s = String(v == null ? '' : v);
    return '"' + s.replace(/"/g, '""') + '"';
  }

  function downloadCsv() {
    var events = state.bitacora.filtrados || [];
    if (!events.length) { toast('No hay eventos para exportar.', 'error'); return; }
    var rows = [['seq', 'ts_evento_iso', 'ts_recepcion_iso', 'dispositivo', 'tipo_dispositivo', 'edificio', 'tipo_evento', 'persona', 'desfasado', 'hash']];
    events.forEach(function (ev) {
      rows.push([ev.seq, ev.ts_evento_iso, ev.ts_recepcion_iso, ev.dispositivo_id, ev.tipo_dispositivo, ev.edificio, ev.tipo_evento, ev.persona || '', ev.desfasado, ev.hash]);
    });
    var csv = rows.map(function (r) { return r.map(csvEscape).join(','); }).join('\r\n');
    var blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = 'bitacora-p69-' + new Date().toISOString().replace(/[:.]/g, '-') + '.csv';
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
    toast('CSV exportado con ' + events.length + ' eventos.', 'info');
  }

  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) return navigator.clipboard.writeText(text);
    return new Promise(function (resolve, reject) {
      var ta = document.createElement('textarea');
      ta.value = text;
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      try { document.execCommand('copy'); resolve(); } catch (e) { reject(e); }
      ta.remove();
    });
  }

  function initBitacora() {
    var q = new URLSearchParams(location.search);
    setPreset(q.get('rango') || '1h');
    if (q.get('dispositivo')) {
      state.bitacora.busqueda = q.get('dispositivo');
      var search = $('#bitacora-search');
      if (search) search.value = state.bitacora.busqueda;
    }
    if (q.get('severidad')) state.bitacora.severidad = q.get('severidad');
    if (q.get('tipo')) state.bitacora.tipo = q.get('tipo');

    $$('.preset-pill[data-preset]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        setPreset(btn.dataset.preset);
        cargarBitacora();
      });
    });
    var toggle = $('#toggle-custom-range');
    var panel = $('#custom-range-panel');
    if (toggle && panel) {
      toggle.addEventListener('click', function () {
        var hidden = panel.classList.contains('is-hidden');
        panel.classList.toggle('is-hidden', !hidden);
        panel.classList.toggle('flex', hidden);
        toggle.classList.toggle('bg-primary-container', hidden);
        toggle.classList.toggle('text-on-primary', hidden);
        toggle.classList.toggle('bg-surface-container', !hidden);
        toggle.classList.toggle('text-primary', !hidden);
      });
    }
    var apply = $('#apply-range');
    if (apply) {
      apply.addEventListener('click', function () {
        var desde = $('#range-desde').value;
        var hasta = $('#range-hasta').value;
        var d1 = desde ? new Date(desde) : null;
        var d2 = hasta ? new Date(hasta) : null;
        if (!d1 || !d2 || isNaN(d1.getTime()) || isNaN(d2.getTime()) || d1 > d2) {
          toast('Indica un rango valido: desde <= hasta.', 'error');
          return;
        }
        state.bitacora.desde = d1.getTime() * 1000;
        state.bitacora.hasta = d2.getTime() * 1000;
        state.bitacora.preset = 'custom';
        $$('.preset-pill[data-preset]').forEach(function (b) { b.classList.remove('bg-primary-container', 'text-on-primary', 'font-bold', 'shadow-sm'); });
        updateRangeLabel();
        cargarBitacora();
      });
    }
    var search = $('#bitacora-search');
    if (search) {
      var t = null;
      search.addEventListener('input', function () {
        clearTimeout(t);
        t = setTimeout(function () {
          state.bitacora.busqueda = search.value.trim();
          renderBitacora();
        }, 180);
      });
    }
    var clear = $('#clear-search');
    if (clear) {
      clear.addEventListener('click', function () {
        if (search) search.value = '';
        state.bitacora.busqueda = '';
        renderBitacora();
      });
    }
    $$('.filter-severity').forEach(function (btn) {
      btn.addEventListener('click', function () {
        state.bitacora.severidad = btn.dataset.severidad || 'todos';
        $$('.filter-severity').forEach(function (b) {
          var active = b === btn;
          b.classList.toggle('ring-1', active);
          b.classList.toggle('ring-primary', active);
          b.classList.toggle('opacity-100', active);
          b.classList.toggle('opacity-60', !active);
        });
        renderBitacora();
      });
    });
    $$('.filter-tipo').forEach(function (btn) {
      btn.addEventListener('click', function () {
        state.bitacora.tipo = btn.dataset.tipo || 'todos';
        $$('.filter-tipo').forEach(function (b) {
          var active = b === btn;
          b.classList.toggle('bg-surface-container-high', active);
          b.classList.toggle('text-primary', active);
          b.classList.toggle('font-semibold', active);
          b.classList.toggle('bg-surface-container', !active);
          b.classList.toggle('text-on-surface-variant', !active);
        });
        renderBitacora();
      });
    });
    var dl = $('#download-csv');
    if (dl) dl.addEventListener('click', downloadCsv);

    var sevBtn = $('.filter-severity[data-severidad="' + state.bitacora.severidad + '"]');
    if (sevBtn) sevBtn.click();
    var tipoBtn = $('.filter-tipo[data-tipo="' + state.bitacora.tipo + '"]');
    if (tipoBtn) tipoBtn.click();
    var desdeInput = $('#range-desde');
    var hastaInput = $('#range-hasta');
    if (desdeInput) desdeInput.value = localInputValue(state.bitacora.desde);
    if (hastaInput) hastaInput.value = localInputValue(state.bitacora.hasta);

    cargarBitacora();
    connectWS({
      onEvent: function (ev) {
        var ts = Number(ev.ts_corregido) || 0;
        if (ts < state.bitacora.desde || ts > state.bitacora.hasta) return;
        state.bitacora.eventos.unshift(ev);
        state.bitacora.total += 1;
        renderBitacora();
      }
    });
    setInterval(function () {
      if (state.bitacora.preset !== 'custom' && state.bitacora.preset !== 'hoy') {
        setPreset(state.bitacora.preset);
        cargarBitacora();
      }
    }, 60000);
  }

  /* ------------------------------------------------------------------ */
  /* Detalle de nodo                                                    */
  /* ------------------------------------------------------------------ */

  function startClock() {
    function tick() { setText('video-clock', fmtTime(new Date(), true)); }
    tick();
    setInterval(tick, 1000);
  }

  function nodeStatusText(estado) {
    if (estado === 'falla') return 'NODO EN FALLA / SIN LATIDO';
    if (estado === 'alerta') return 'NODO EN ALERTA OPERATIVA';
    return 'NODO OPERATIVO';
  }

  function renderNodo(dev, eventos) {
    var tone = deviceTone(dev.estado);
    setText('node-status-label', nodeStatusText(dev.estado));
    setText('node-title', dev.id + ': ' + dev.edificio);
    setText('node-subtitle', tipoDispositivo(dev.tipo) + ' • ' + dev.edificio + ' • Erlang/OTP gen_server');
    setText('node-memory', 'OFFSET ' + fmtOffset(dev.offset_segundos));
    var statusIcon = $('#node-status-icon');
    if (statusIcon) {
      statusIcon.textContent = dev.estado === 'falla' ? 'link_off' : dev.estado === 'alerta' ? 'warning' : 'check_circle';
      statusIcon.className = 'material-symbols-outlined text-[18px] ' + tone.text;
    }
    var statusBox = $('#node-status-box');
    if (statusBox) statusBox.className = 'w-8 h-8 rounded-full bg-surface-container-high flex items-center justify-center flex-shrink-0';
    setText('node-status-detail', dev.estado === 'falla' ? 'Sin latido reciente; el supervisor puede reiniciar el gen_server del nodo.' : dev.estado === 'alerta' ? 'Ultimo evento de alarma o reloj desfasado detectado por la bitacora.' : 'Latido y telemetria dentro de los parametros configurados.');

    setText('telemetry-total', fmtNumber(sumCounters(dev.contadores)));
    setText('telemetry-last', fmtRelative(dev.ultimo_latido_iso));
    setText('telemetry-offset', fmtOffset(dev.offset_segundos));
    setText('telemetry-state', estadoDispositivo(dev.estado));
    var off = Math.abs(Number(dev.offset_segundos) || 0);
    var offEl = $('#telemetry-offset');
    if (offEl) offEl.className = 'font-stat-lg text-stat-lg ' + (off > 1 ? 'text-secondary' : 'text-tertiary');
    var stateEl = $('#telemetry-state');
    if (stateEl) stateEl.className = 'font-headline-sm text-headline-sm ' + tone.text + ' font-bold truncate';

    var list = eventos && eventos.length ? eventos : (dev.recientes || []);
    var cont = $('#node-events');
    if (cont) {
      if (!list.length) {
        cont.innerHTML = '<div class="p-space-sm text-center text-on-surface-variant font-body-sm text-body-sm">Sin eventos recientes para este nodo.</div>';
      } else {
        cont.innerHTML = list.slice(0, 6).map(function (ev) {
          var meta = eventMeta(ev);
          return '<div class="flex items-center justify-between p-space-sm rounded-lg bg-surface-container-low gap-space-sm">' +
            '<div class="flex items-center gap-space-sm min-w-0">' +
              '<span class="font-mono-timestamp text-mono-timestamp text-on-surface-variant font-mono shrink-0">' + esc(fmtTime(ev.ts_corregido_iso, false)) + '</span>' +
              '<div class="w-7 h-7 rounded ' + meta.tone.badge + ' flex items-center justify-center flex-shrink-0">' +
                '<span class="material-symbols-outlined text-[16px]">' + meta.icon + '</span>' +
              '</div>' +
              '<div class="flex flex-col min-w-0">' +
                '<span class="font-body-md text-body-md text-on-surface font-medium truncate">' + esc(ev.tipo_evento) + (ev.persona ? ' • ' + esc(ev.persona) : '') + '</span>' +
                '<span class="font-mono-timestamp text-mono-timestamp text-on-surface-variant truncate">' + esc(fmtRelative(ev.ts_recepcion_iso)) + ' • SEQ ' + esc(ev.seq) + '</span>' +
              '</div>' +
            '</div>' +
            '<span class="font-label-caps text-label-caps px-2 py-0.5 rounded-full ' + meta.tone.badge + ' flex-shrink-0">' + meta.tone.label + '</span>' +
          '</div>';
        }).join('');
      }
    }
    var bit = $('#node-bitacora-link');
    if (bit) bit.href = 'bitacora.html?dispositivo=' + encodeURIComponent(dev.id);
    var copy = $('#btn-copy-id');
    if (copy) copy.dataset.id = dev.id;
  }

  function initNodo() {
    var q = new URLSearchParams(location.search);
    state.nodo.id = q.get('id') || '';
    state.nodo.edificio = q.get('edificio') || '';
    startClock();
    pageStatus('loading', 'Cargando detalle del nodo...');

    var ensure = state.nodo.id
      ? Promise.resolve({ id: state.nodo.id, edificio: state.nodo.edificio })
      : api('/api/dispositivos').then(function (data) {
          var devs = data.dispositivos || [];
          var pick = devs.filter(function (d) { return d.estado === 'falla'; })[0] ||
            devs.filter(function (d) { return d.estado === 'alerta'; })[0] || devs[0];
          if (!pick) throw new Error('No hay dispositivos registrados. Ejecuta el simulador primero.');
          return { id: pick.id, edificio: pick.edificio };
        });

    ensure.then(function (sel) {
      state.nodo.id = sel.id;
      state.nodo.edificio = sel.edificio;
      var params = new URLSearchParams(location.search);
      params.set('id', sel.id);
      if (sel.edificio) params.set('edificio', sel.edificio);
      history.replaceState(null, '', location.pathname + '?' + params.toString());
      var url = '/api/dispositivos/' + encodeURIComponent(sel.id) + (sel.edificio ? '?edificio=' + encodeURIComponent(sel.edificio) : '');
      return Promise.all([api(url), api('/api/eventos?desde=' + (microsNow() - 24 * 3600 * 1000000) + '&hasta=' + microsNow() + '&dispositivo=' + encodeURIComponent(sel.id) + (sel.edificio ? '&edificio=' + encodeURIComponent(sel.edificio) : '') + '&limite=50')]);
    }).then(function (res) {
      var dev = res[0];
      var eventos = (res[1] && res[1].eventos) || [];
      renderNodo(dev, eventos);
      pageStatus('hidden');
      refreshAlertsBadge();
    }).catch(function (err) {
      pageStatus('error', 'No se pudo cargar el nodo: ' + err.message, initNodo);
    });

    var verify = $('#btn-verify');
    if (verify) {
      verify.addEventListener('click', function () {
        setText('verify-result', 'Verificando cadena SHA-256...');
        api('/api/bitacora/verificar').then(function (data) {
          if (data.integridad === 'ok') {
            setText('verify-result', 'Cadena integra: ' + fmtNumber(data.resumen.eventos || 0) + ' eventos verificados.');
            toast('Cadena SHA-256 verificada correctamente.', 'info');
          } else {
            setText('verify-result', 'La verificacion reporto una falla.');
            toast('La cadena reporto una falla. Revisa /api/bitacora/verificar.', 'error');
          }
        }).catch(function (err) {
          setText('verify-result', 'No se pudo verificar: ' + err.message);
          toast('No se pudo verificar la cadena.', 'error');
        });
      });
    }
    var copy = $('#btn-copy-id');
    if (copy) {
      copy.addEventListener('click', function () {
        var id = copy.dataset.id || state.nodo.id;
        copyText(id).then(function () { toast('ID copiado: ' + id, 'info'); })
          .catch(function () { toast('No se pudo copiar el ID.', 'error'); });
      });
    }
    $$('[data-honest]').forEach(function (el) {
      el.addEventListener('click', function (e) {
        e.preventDefault();
        toast('Control fisico/PTZ no expuesto por la API de esta demo.', 'error');
      });
    });
    connectWS({});
  }

  /* ------------------------------------------------------------------ */

  function init() {
    if (page === 'dashboard') initDashboard();
    if (page === 'bitacora') initBitacora();
    if (page === 'nodo') initNodo();
    if (page !== 'dashboard') refreshAlertsBadge();
    window.addEventListener('beforeunload', disconnectWS);
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
