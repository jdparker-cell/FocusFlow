async function focusReelsTab(senderTab) {
  const matches = await chrome.tabs.query({
    url: [
      "https://*.instagram.com/reels/*",
      "https://*.instagram.com/reel/*",
    ],
  });
  const tab = senderTab?.id ? senderTab : matches[0];
  if (!tab?.id || tab.windowId === undefined) return;

  await chrome.windows.update(tab.windowId, {
    focused: true,
    state: "maximized",
  });
  await chrome.tabs.update(tab.id, { active: true });
}

chrome.runtime.onMessage.addListener((message, sender) => {
  if (message?.type !== "focus-this-reels-tab") return;
  focusReelsTab(sender.tab).catch(() => {});
});
