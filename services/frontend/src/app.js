"use strict";

// Endpoints routed by the ingress to the backend services.
const ENDPOINTS = [
  { path: "/api/hello", outputId: "hello-output", cardId: "card-hello" },
  { path: "/api/time", outputId: "time-output", cardId: "card-time" },
];

async function loadEndpoint({ path, outputId, cardId }) {
  const output = document.getElementById(outputId);
  const card = document.getElementById(cardId);
  output.textContent = "Loading…";
  card.classList.remove("error");

  try {
    const res = await fetch(path, { headers: { Accept: "application/json" } });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status} ${res.statusText}`);
    }
    const data = await res.json();
    output.textContent = JSON.stringify(data, null, 2);
  } catch (err) {
    card.classList.add("error");
    output.textContent = `Error fetching ${path}: ${err.message}`;
  }
}

function loadAll() {
  ENDPOINTS.forEach(loadEndpoint);
}

document.addEventListener("DOMContentLoaded", () => {
  document.getElementById("refresh").addEventListener("click", loadAll);
  loadAll();
});
