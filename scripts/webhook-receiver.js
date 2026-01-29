#!/usr/bin/env node
/**
 * Simple webhook receiver for testing Kan webhooks
 * Usage: node webhook-receiver.js [port]
 * Default port: 3333
 */

const http = require('http');
const crypto = require('crypto');

const PORT = process.argv[2] || 3333;
const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET;

function verifySignature(payload, signature, secret) {
  if (!secret || !signature) return null;
  const expected = crypto.createHmac('sha256', secret).update(payload).digest('hex');
  return signature === expected;
}

const server = http.createServer((req, res) => {
  if (req.method !== 'POST') {
    res.writeHead(200);
    res.end('Webhook receiver running. Send POST requests here.\n');
    return;
  }

  let body = '';
  req.on('data', chunk => body += chunk);
  req.on('end', () => {
    const timestamp = new Date().toISOString();
    const event = req.headers['x-webhook-event'] || 'unknown';
    const signature = req.headers['x-webhook-signature'];

    console.log('\n' + '='.repeat(60));
    console.log(`[${timestamp}] Received: ${event}`);
    console.log('='.repeat(60));

    // Verify signature if secret is configured
    if (WEBHOOK_SECRET) {
      const valid = verifySignature(body, signature, WEBHOOK_SECRET);
      console.log(`Signature: ${valid ? '✓ Valid' : '✗ Invalid'}`);
    }

    // Pretty print the payload
    try {
      const payload = JSON.parse(body);
      console.log('\nPayload:');
      console.log(JSON.stringify(payload, null, 2));
    } catch (e) {
      console.log('\nRaw body:', body);
    }

    console.log('='.repeat(60) + '\n');

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ received: true }));
  });
});

server.listen(PORT, () => {
  console.log(`\n🎣 Webhook receiver listening on http://localhost:${PORT}`);
  console.log(`   POST webhooks to this URL`);
  if (WEBHOOK_SECRET) {
    console.log(`   Signature verification: enabled`);
  } else {
    console.log(`   Signature verification: disabled (set WEBHOOK_SECRET to enable)`);
  }
  console.log('\nWaiting for webhooks...\n');
});
