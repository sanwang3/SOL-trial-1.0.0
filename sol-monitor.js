#!/usr/bin/env node
/**
 * Solana 实时监控：转账签名 + 区块哈希
 * ---------------------------------------------
 * 1. logsSubscribe(processed) 监听涉及 A 地址的交易签名，亚秒级推送
 * 2. slotSubscribe + getBlock，出块后即刻推送 blockhash
 * 3. 自动重连(指数退避) + 心跳保活 + pong 超时检测
 * 4. 去重：签名 LRU / blockhash LRU / slot 单调递增
 * 5. slot 队列削峰，RPC 变慢时不积压
 * 6. 可选 VERIFY=1：调 getTransaction 精确确认是 transfer（多 100~300ms）
 *
 * 运行：npm i ws && WATCH_ADDR=<A地址> node sol-monitor.js
 * 生产请换私有 RPC（Helius/QuickNode/自建），公共节点有速率限制
 */
const WebSocket = require('ws');

const CFG = {
  wsUrl:     process.env.SOL_WS   || 'wss://api.mainnet-beta.solana.com',
  httpUrl:   process.env.SOL_HTTP || 'https://api.mainnet-beta.solana.com',
  watchAddr: process.env.WATCH_ADDR || '',
  commitment: 'processed',
  verifyTransfer: process.env.VERIFY === '1',
  hbMs: 15000, pongMs: 5000, maxBackoff: 30000,
};
if (!CFG.watchAddr) { console.error('请先设置 WATCH_ADDR 环境变量'); process.exit(1); }

const sleep = ms => new Promise(r => setTimeout(r, ms));
let rpcId = 0;

class LruSet {
  constructor(cap) { this.cap = cap; this.set = new Set(); }
  add(k) {
    if (this.set.has(k)) return false;
    this.set.add(k);
    if (this.set.size > this.cap) this.set.delete(this.set.values().next().value);
    return true;
  }
}

async function httpRpc(method, params) {
  const res = await fetch(CFG.httpUrl, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', id: ++rpcId, method, params }),
  });
  if (!res.ok) throw new Error('HTTP ' + res.status);
  const j = await res.json();
  if (j.error) throw new Error(j.error.message);
  return j.result;
}

class SolMonitor {
  constructor() {
    this.pending = new Map();
    this.subIds = {};
    this.sigs = new LruSet(20000);
    this.hashes = new LruSet(1000);
    this.lastSlot = 0; this.queue = []; this.busy = false;
    this.backoff = 1000; this.stopped = false;
  }
  start() { this._connect(); }

  _connect() {
    if (this.stopped) return;
    this.ws = new WebSocket(CFG.wsUrl);
    this.ws.on('open', () => {
      console.log('[ws] connected');
      this.backoff = 1000;
      this.pending = new Map(); this.subIds = {};
      this._send('logsSubscribe', [{ mentions: [CFG.watchAddr] }, { commitment: CFG.commitment }], 'logs');
      this._send('slotSubscribe', [], 'slot');
      this._heartbeat();
    });
    this.ws.on('message', d => this._onMsg(d));
    this.ws.on('pong', () => { this.lastPong = Date.now(); });
    this.ws.on('error', e => console.error('[ws] err:', e.message));
    this.ws.on('close', () => {
      this._stopHb();
      if (this.stopped) return;
      console.log(`[ws] 断开，${this.backoff}ms 后重连`);
      setTimeout(() => this._connect(), this.backoff);
      this.backoff = Math.min(this.backoff * 2, CFG.maxBackoff);
    });
  }
  _heartbeat() {
    this._stopHb(); this.lastPong = Date.now();
    this.hb = setInterval(() => {
      if (Date.now() - this.lastPong > CFG.hbMs + CFG.pongMs) {
        console.warn('[ws] pong 超时，强制重连'); this.ws.terminate(); return;
      }
      try { this.ws.ping(); } catch {}
    }, CFG.hbMs);
  }
  _stopHb() { if (this.hb) { clearInterval(this.hb); this.hb = null; } }
  _send(method, params, type) {
    const id = ++rpcId;
    this.pending.set(id, type);
    this.ws.send(JSON.stringify({ jsonrpc: '2.0', id, method, params }));
  }

  _onMsg(raw) {
    let m; try { m = JSON.parse(raw); } catch { return; }
    if (m.id != null && typeof m.result === 'number') {
      const t = this.pending.get(m.id);
      if (t) { this.subIds[m.result] = t; this.pending.delete(m.id); console.log('[sub] ok:', t); }
      return;
    }
    if (m.method === 'logsNotification') this._onLog(m.params.result.value);
    else if (m.method === 'slotNotification') this._onSlot(m.params.result.value.slot);
  }

  _onLog(v) {
    if (!this.sigs.add(v.signature)) return;
    console.log(`${v.err ? '[tx-failed]' : '[tx]'} ${new Date().toISOString()} sig=${v.signature}`);
    if (CFG.verifyTransfer && !v.err) this._verify(v.signature);
  }
  async _verify(sig) {
    try {
      const tx = await httpRpc('getTransaction',
        [sig, { encoding: 'jsonParsed', commitment: 'confirmed', maxSupportedTransactionVersion: 0 }]);
      if (!tx) return;
      const ins = [...tx.transaction.message.instructions,
                   ...(tx.meta?.innerInstructions?.flatMap(x => x.instructions) || [])];
      for (const i of ins) {
        const p = i.parsed; if (!p || p.type !== 'transfer') continue;
        const isSol = i.program === 'system';
        console.log(`  ↳ 转账 ${isSol ? 'SOL' : 'SPL'}: ${p.info.source} -> ${p.info.destination} ` +
                    (isSol ? `${p.info.lamports} lamports` : `amount=${p.info.amount}`));
      }
    } catch (e) { /* 校验失败不阻断主流程 */ }
  }

  _onSlot(slot) {
    if (slot <= this.lastSlot) return;
    this.lastSlot = slot;
    this.queue.push(slot);
    if (this.queue.length > 100) this.queue.splice(0, this.queue.length - 20);
    this._pump();
  }
  async _pump() {
    if (this.busy) return;
    this.busy = true;
    while (this.queue.length) {
      const slot = this.queue.shift();
      for (let retry = 0; retry < 2; retry++) {
        try {
          const b = await httpRpc('getBlock',
            [slot, { encoding: 'json', transactionDetails: 'none', rewards: false, commitment: 'confirmed' }]);
          if (b && this.hashes.add(b.blockhash))
            console.log(`[block] slot=${slot} blockhash=${b.blockhash}`);
          break;
        } catch (e) { if (retry === 0) await sleep(300); }
      }
    }
    this.busy = false;
  }
}

const mon = new SolMonitor();
mon.start();
process.on('SIGINT', () => { mon.stopped = true; mon.ws?.close(); process.exit(0); });
