import { chromium } from '/tmp/node_modules/playwright/index.mjs';

const SCREENS = [
  ['s-home',      '01-dashboard'],
  ['s-capture',   '02-capture'],
  ['s-analysing', '03-analysing'],
  ['s-result',    '04-reading'],
  ['s-history',   '05-history'],
  ['s-settings',  '06-settings'],
];

const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
const page = await browser.newPage({
  viewport: { width: 430, height: 932 },
  deviceScaleFactor: 3,          // 430x932 @3x == 1290x2796, an App Store size
});
await page.goto('file://' + process.cwd() + '/mockups.html');
await page.waitForTimeout(600);

for (const [id, name] of SCREENS) {
  const el = await page.$('#' + id);
  if (!el) { console.error('missing', id); continue; }
  await el.screenshot({ path: `${name}.png` });
  console.log('shot', name);
}
await browser.close();
