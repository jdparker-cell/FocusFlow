let shouldResume = false;

function playPauseButton() {
  return document.querySelector(
    '[data-testid="control-button-playpause"], button[aria-label="Pause"], button[aria-label="Play"]',
  );
}

function spotifyIsPlaying() {
  const button = playPauseButton();
  if (button?.getAttribute("aria-label") === "Pause") return true;
  return [...document.querySelectorAll("audio, video")].some(
    (media) => !media.paused && !media.ended,
  );
}

function pauseSpotify() {
  if (!spotifyIsPlaying()) return;
  shouldResume = true;

  const button = playPauseButton();
  if (button?.getAttribute("aria-label") === "Pause") button.click();
  document.querySelectorAll("audio, video").forEach((media) => media.pause());
}

function resumeSpotify() {
  if (!shouldResume) return;
  shouldResume = false;

  const button = playPauseButton();
  if (button?.getAttribute("aria-label") === "Play") {
    button.click();
    return;
  }

  document.querySelectorAll("audio, video").forEach((media) => {
    media.play().catch(() => {});
  });
}

function handleState(state) {
  if (state.active) pauseSpotify();
  else resumeSpotify();
}

function connect() {
  const events = new EventSource("http://127.0.0.1:38473/events");
  events.onmessage = ({ data }) => {
    try {
      handleState(JSON.parse(data));
    } catch {
      // Wait for the next valid state event.
    }
  };
  events.onerror = () => {
    events.close();
    setTimeout(connect, 1000);
  };
}

fetch("http://127.0.0.1:38473/state", { cache: "no-store" })
  .then((response) => response.json())
  .then(handleState)
  .catch(() => {});
connect();
