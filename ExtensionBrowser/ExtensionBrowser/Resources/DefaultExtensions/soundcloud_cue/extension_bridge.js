/**
 * Chrome & WebExtension Compatibility Bridge for iOS WKWebView
 * Hỗ trợ toàn diện Manifest V2 & V3 (Callback + Promise)
 */
(function() {
  'use strict';
  if (window.__webExtensionBridgeInitialized) return;
  window.__webExtensionBridgeInitialized = true;

  console.log('[WebExtensionBridge] Khởi tạo Chrome Extension API Shim cho WKWebView...');

  // Lưu trữ listeners
  const storageListeners = [];
  const messageListeners = [];
  let currentManifest = window.__EXTENSION_MANIFEST__ || {
    name: 'SoundCloud Crossfader',
    version: '4.1',
    manifest_version: 2
  };

  const extensionId = window.__EXTENSION_ID__ || 'sc-crossfader-default';

  // Helper hỗ trợ vừa Callback vừa Promise
  function promisify(fn) {
    return function(...args) {
      let callback = null;
      if (typeof args[args.length - 1] === 'function') {
        callback = args.pop();
      }
      return new Promise((resolve, reject) => {
        const wrappedCallback = (res) => {
          if (chrome.runtime.lastError) {
            if (callback) callback(res);
            reject(chrome.runtime.lastError);
          } else {
            if (callback) callback(res);
            resolve(res);
          }
        };
        try {
          fn(...args, wrappedCallback);
        } catch (err) {
          if (callback) callback(undefined);
          reject(err);
        }
      });
    };
  }

  // 1. CHROME.STORAGE SHIM (local, sync, session)
  function createStorageArea(areaName) {
    const storageKey = '__ext_storage_' + extensionId + '_' + areaName;

    function getStorageData() {
      try {
        const raw = localStorage.getItem(storageKey) || localStorage.getItem('sc_cue_storage');
        return raw ? JSON.parse(raw) : {};
      } catch (e) {
        console.error('[WebExtensionBridge] Lỗi đọc storage:', e);
        return {};
      }
    }

    function saveStorageData(data) {
      try {
        const raw = JSON.stringify(data);
        localStorage.setItem(storageKey, raw);
        // Lưu tương thích ngược cho SoundCloud extension
        localStorage.setItem('sc_cue_storage', raw);
        
        // Gửi sang Swift Native để lưu vào UserDefaults
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.nativeStorage) {
          window.webkit.messageHandlers.nativeStorage.postMessage({
            extensionId: extensionId,
            area: areaName,
            data: raw
          });
        }
      } catch (e) {
        console.error('[WebExtensionBridge] Lỗi ghi storage:', e);
      }
    }

    return {
      get: promisify(function(keys, callback) {
        let all = getStorageData();
        let result = {};

        if (!keys) {
          result = all;
        } else if (typeof keys === 'string') {
          result = { [keys]: all[keys] };
        } else if (Array.isArray(keys)) {
          keys.forEach(k => { result[k] = all[k]; });
        } else if (typeof keys === 'object') {
          result = { ...keys };
          for (let k in keys) {
            if (k in all) result[k] = all[k];
          }
        }
        setTimeout(() => callback(result), 0);
      }),

      set: promisify(function(items, callback) {
        if (!items || typeof items !== 'object') {
          if (callback) setTimeout(callback, 0);
          return;
        }

        let current = getStorageData();
        let changes = {};
        for (let k in items) {
          changes[k] = {
            oldValue: current[k],
            newValue: items[k]
          };
          current[k] = items[k];
        }

        saveStorageData(current);

        // Kích hoạt listeners tại trang hiện tại
        storageListeners.forEach(listener => {
          try {
            listener(changes, areaName);
          } catch (err) {
            console.error('[WebExtensionBridge] Lỗi listener onChanged:', err);
          }
        });

        setTimeout(callback, 0);
      }),

      remove: promisify(function(keys, callback) {
        let current = getStorageData();
        let keyList = Array.isArray(keys) ? keys : [keys];
        let changes = {};
        keyList.forEach(k => {
          if (k in current) {
            changes[k] = { oldValue: current[k], newValue: undefined };
            delete current[k];
          }
        });
        saveStorageData(current);

        storageListeners.forEach(listener => {
          try { listener(changes, areaName); } catch (err) {}
        });

        setTimeout(callback, 0);
      }),

      clear: promisify(function(callback) {
        let current = getStorageData();
        let changes = {};
        for (let k in current) {
          changes[k] = { oldValue: current[k], newValue: undefined };
        }
        localStorage.removeItem(storageKey);
        localStorage.removeItem('sc_cue_storage');

        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.nativeStorage) {
          window.webkit.messageHandlers.nativeStorage.postMessage({
            extensionId: extensionId,
            area: areaName,
            data: '{}'
          });
        }

        storageListeners.forEach(listener => {
          try { listener(changes, areaName); } catch (err) {}
        });

        setTimeout(callback, 0);
      }),

      getBytesInUse: promisify(function(keys, callback) {
        const raw = localStorage.getItem(storageKey) || '';
        setTimeout(() => callback(raw.length), 0);
      })
    };
  }

  const localStorageArea = createStorageArea('local');
  const syncStorageArea = createStorageArea('sync');
  const sessionStorageArea = createStorageArea('session');

  const storageShim = {
    local: localStorageArea,
    sync: syncStorageArea,
    session: sessionStorageArea,
    onChanged: {
      addListener: function(fn) {
        if (typeof fn === 'function' && !storageListeners.includes(fn)) {
          storageListeners.push(fn);
        }
      },
      removeListener: function(fn) {
        const idx = storageListeners.indexOf(fn);
        if (idx !== -1) storageListeners.splice(idx, 1);
      },
      hasListener: function(fn) {
        return storageListeners.includes(fn);
      }
    }
  };

  // 2. CHROME.RUNTIME SHIM
  let liveClientId = null;
  const runtimeShim = {
    id: extensionId,
    lastError: null,
    getManifest: function() {
      return currentManifest;
    },
    getURL: function(path) {
      if (!path) return '';
      if (path.startsWith('http://') || path.startsWith('https://')) return path;
      const cleanPath = path.startsWith('/') ? path.slice(1) : path;
      return 'extension://' + extensionId + '/' + cleanPath;
    },
    sendMessage: promisify(function(msg, callback) {
      if (!msg) {
        if (callback) callback();
        return;
      }

      // Xử lý thông điệp nội bộ cho SoundCloud Crossfader
      if (msg.type === 'SET_LIVE_CLIENT_ID') {
        liveClientId = msg.clientId;
        console.log('[WebExtensionBridge] Live Client ID cập nhật:', liveClientId);
        if (callback) callback({ success: true });
        return;
      }

      if (msg.type === 'RESOLVE_STREAM_URL') {
        resolveTrackStream(msg.trackUrl, msg.clientId)
          .then(res => { if (callback) callback({ success: true, ...res }); })
          .catch(err => { if (callback) callback({ success: false, error: err.message }); });
        return;
      }

      // Gửi sang iOS Native để dispatch tới các tab hoặc background/popup khác
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.chromeRuntime) {
        window.webkit.messageHandlers.chromeRuntime.postMessage({
          type: 'RUNTIME_SEND_MESSAGE',
          extensionId: extensionId,
          payload: msg
        });
      }

      // Gọi local onMessage listeners
      let responseHandled = false;
      const sendResponse = (resp) => {
        if (!responseHandled) {
          responseHandled = true;
          if (callback) callback(resp);
        }
      };

      messageListeners.forEach(listener => {
        try {
          const keepChannelOpen = listener(msg, { id: extensionId, tab: { id: 1 } }, sendResponse);
          if (keepChannelOpen === true) {
            // Callback sẽ được gọi bất đồng bộ bởi extension
          }
        } catch (err) {
          console.error('[WebExtensionBridge] Lỗi onMessage listener:', err);
        }
      });

      if (!responseHandled && callback) {
        setTimeout(() => callback({ acknowledged: true }), 10);
      }
    }),

    onMessage: {
      addListener: function(fn) {
        if (typeof fn === 'function' && !messageListeners.includes(fn)) {
          messageListeners.push(fn);
        }
      },
      removeListener: function(fn) {
        const idx = messageListeners.indexOf(fn);
        if (idx !== -1) messageListeners.splice(idx, 1);
      },
      hasListener: function(fn) {
        return messageListeners.includes(fn);
      }
    }
  };

  // 3. CHROME.TABS SHIM
  const tabsShim = {
    query: promisify(function(queryInfo, callback) {
      const activeTab = {
        id: 1,
        index: 0,
        active: true,
        highlighted: true,
        url: window.location.href,
        title: document.title,
        status: 'complete'
      };
      setTimeout(() => callback([activeTab]), 0);
    }),

    get: promisify(function(tabId, callback) {
      setTimeout(() => callback({
        id: tabId || 1,
        url: window.location.href,
        title: document.title
      }), 0);
    }),

    sendMessage: promisify(function(tabId, message, callback) {
      // Gửi message tới web content script hoặc native bridge
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.chromeRuntime) {
        window.webkit.messageHandlers.chromeRuntime.postMessage({
          type: 'TAB_SEND_MESSAGE',
          tabId: tabId || 1,
          payload: message
        });
      }

      // Cũng phát window.postMessage để nội dung trong page (như inject.js) nhận được
      window.postMessage(message, '*');

      let handled = false;
      const sendResponse = (resp) => {
        if (!handled) {
          handled = true;
          if (callback) callback(resp);
        }
      };

      messageListeners.forEach(fn => {
        try { fn(message, { id: extensionId, tab: { id: 1 } }, sendResponse); } catch(e) {}
      });

      if (!handled && callback) {
        setTimeout(() => callback({ success: true }), 10);
      }
    }),

    create: promisify(function(createProperties, callback) {
      if (createProperties && createProperties.url) {
        window.location.href = createProperties.url;
      }
      setTimeout(() => callback({ id: 1, url: window.location.href }), 0);
    }),

    update: promisify(function(tabId, updateProperties, callback) {
      if (updateProperties && updateProperties.url) {
        window.location.href = updateProperties.url;
      }
      setTimeout(() => callback({ id: tabId || 1, url: window.location.href }), 0);
    })
  };

  // 4. ACTION / BROWSER_ACTION SHIM
  const actionShim = {
    setTitle: function(details) {},
    setIcon: function(details) {},
    setBadgeText: function(details) {},
    setBadgeBackgroundColor: function(details) {},
    openPopup: function() {
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.chromeRuntime) {
        window.webkit.messageHandlers.chromeRuntime.postMessage({
          type: 'OPEN_POPUP',
          extensionId: extensionId
        });
      }
    }
  };

  // 5. I18N SHIM
  const i18nShim = {
    getMessage: function(messageName, substitutions) {
      return messageName;
    },
    getUILanguage: function() {
      return navigator.language || 'vi';
    }
  };

  // Hỗ trợ giải mã stream SoundCloud (từ SoundCloudVH.ipa)
  const FALLBACK_CLIENT_IDS = [
    'iZIs9mchVcX5lhVR1HNjwtb1nfq09BQ1',
    'b426b38c957b6971e45f944d00718880',
    '2t9loNfh0ekOfHG3lJLUpNu4bg84fqeO'
  ];
  const streamCache = new Map();

  async function resolveTrackStream(rawUrl, providedClientId) {
    const cleanPath = rawUrl.startsWith('http') ? rawUrl : `https://soundcloud.com${rawUrl.startsWith('/') ? '' : '/'}${rawUrl}`;
    if (streamCache.has(cleanPath)) {
      const cached = streamCache.get(cleanPath);
      if (Date.now() - cached.time < 5 * 60 * 1000) return cached.data;
    }
    const clientId = providedClientId || liveClientId || FALLBACK_CLIENT_IDS[0];
    const resolveApi = `https://api-v2.soundcloud.com/resolve?url=${encodeURIComponent(cleanPath)}&client_id=${clientId}`;
    const resolveResp = await fetch(resolveApi);
    if (!resolveResp.ok) throw new Error(`SoundCloud Resolve thất bại: ${resolveResp.status}`);
    const data = await resolveResp.json();
    const track = data.kind === 'playlist' && data.tracks?.length ? data.tracks[0] : data;
    const transcodings = track.media?.transcodings;
    if (!transcodings || !transcodings.length) throw new Error('Không có audio transcodings');
    const chosen = transcodings.find(t => t.format?.protocol === 'progressive') ||
                   transcodings.find(t => t.format?.protocol === 'hls') ||
                   transcodings[0];
    const sep = chosen.url.includes('?') ? '&' : '?';
    const cdnResp = await fetch(`${chosen.url}${sep}client_id=${clientId}`);
    if (!cdnResp.ok) throw new Error(`Lỗi link stream: ${cdnResp.status}`);
    const cdnData = await cdnResp.json();
    const result = {
      streamUrl: cdnData.url,
      protocol: chosen.format?.protocol || 'hls',
      title: track.title || 'Bài tiếp theo',
      duration: Math.round((track.duration || 0) / 1000),
      permalink: track.permalink_url || cleanPath,
      artwork: track.artwork_url || track.user?.avatar_url || ''
    };
    streamCache.set(cleanPath, { time: Date.now(), data: result });
    return result;
  }

  // Khởi tạo window.chrome và window.browser
  window.chrome = window.chrome || {};
  window.chrome.storage = storageShim;
  window.chrome.runtime = runtimeShim;
  window.chrome.tabs = tabsShim;
  window.chrome.action = actionShim;
  window.chrome.browserAction = actionShim;
  window.chrome.i18n = i18nShim;
  window.chrome.extension = runtimeShim; // alias

  // WebExtension promise-based browser namespace
  window.browser = window.chrome;

  // Phương thức native gọi vào để cập nhật storage khi thay đổi từ tab khác hoặc popup
  window.__dispatchStorageChangeFromNative = function(changesJson, area) {
    try {
      const changes = typeof changesJson === 'string' ? JSON.parse(changesJson) : changesJson;
      storageListeners.forEach(listener => {
        try { listener(changes, area || 'local'); } catch(e) {}
      });
    } catch(e) {
      console.error('[WebExtensionBridge] Lỗi __dispatchStorageChangeFromNative:', e);
    }
  };

  // Phương thức native gọi vào để dispatch runtime message từ popup hoặc tab khác
  window.__dispatchRuntimeMessageFromNative = function(msgJson) {
    try {
      const msg = typeof msgJson === 'string' ? JSON.parse(msgJson) : msgJson;
      messageListeners.forEach(listener => {
        try { listener(msg, { id: extensionId, tab: { id: 1 } }, () => {}); } catch(e) {}
      });
      window.postMessage(msg, '*');
    } catch(e) {
      console.error('[WebExtensionBridge] Lỗi __dispatchRuntimeMessageFromNative:', e);
    }
  };

  console.log('[WebExtensionBridge] Chrome Extension APIs đã sẵn sàng 100%!');
})();
