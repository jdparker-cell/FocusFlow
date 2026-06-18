let lastGeneration = -1;
let wasActive = false;

function handleState(state) {
  if (state.active && state.generation !== lastGeneration) {
    lastGeneration = state.generation;
    wasActive = true;
    chrome.runtime.sendMessage({ type: "focus-this-reels-tab" });
  } else if (!state.active && wasActive) {
    wasActive = false;
    document.querySelectorAll("video, audio").forEach((media) => media.pause());
  }
}

function connect() {
  const events = new EventSource("http://127.0.0.1:38473/events");

  events.onmessage = ({ data }) => {
    try {
      handleState(JSON.parse(data));
    } catch {
      // Ignore malformed events and wait for the next state update.
    }
  };

  events.onerror = () => {
    events.close();
    setTimeout(connect, 1000);
  };
}

async function readInitialState() {
  try {
    const response = await fetch("http://127.0.0.1:38473/state", {
      cache: "no-store",
    });
    handleState(await response.json());
  } catch {
    // The local controller may not be running yet.
  }
}

readInitialState();
connect();
