import { createOptions } from "./createOptions.js";

const optionsWrapper = document.getElementById("options-wrapper");
const vignette = document.getElementById("vignette");
const body = document.body;

let mouseX = window.innerWidth / 2;
let mouseY = window.innerHeight / 2;
let isLocked = false;
let hideTimeout = null;
let lockedX = null;
let lockedY = null;

document.addEventListener("mousemove", (e) => {
  mouseX = e.clientX;
  mouseY = e.clientY;

  if (!isLocked && optionsWrapper.children.length > 0) {
    updateOptionsPosition();
  }
});

function updateOptionsPosition() {
  const offsetX = 20;
  const offsetY = -10;

  const maxX = window.innerWidth - optionsWrapper.offsetWidth - 20;
  const maxY = window.innerHeight - optionsWrapper.offsetHeight - 20;

  let x = Math.min(mouseX + offsetX, maxX);
  let y = Math.min(Math.max(mouseY + offsetY, 20), maxY);

  optionsWrapper.style.left = x + "px";
  optionsWrapper.style.top = y + "px";
}

window.addEventListener("message", (event) => {
  switch (event.data.event) {
    case "visible": {
      if (event.data.state) {
        if (hideTimeout) {
          clearTimeout(hideTimeout);
          hideTimeout = null;
        }
        body.style.visibility = "visible";
        if (event.data.vignette) {
          vignette.classList.add("active");
        }
      } else {
        vignette.classList.remove("active");
        optionsWrapper.innerHTML = "";
        isLocked = false;
        lockedX = null;
        lockedY = null;
        optionsWrapper.classList.remove("locked");
        hideTimeout = setTimeout(() => {
          body.style.visibility = "hidden";
          hideTimeout = null;
        }, 400);
      }
      return;
    }

    case "leftTarget": {
      if (!isLocked) {
        optionsWrapper.innerHTML = "";
      }
      return;
    }

    case "lockOptions": {
      isLocked = true;
      lockedX = optionsWrapper.style.left;
      lockedY = optionsWrapper.style.top;
      optionsWrapper.classList.add("locked");
      return;
    }

    case "unlockOptions": {
      isLocked = false;
      lockedX = null;
      lockedY = null;
      optionsWrapper.classList.remove("locked");
      return;
    }

    case "setTarget": {
      optionsWrapper.innerHTML = "";

      if (event.data.options) {
        for (const type in event.data.options) {
          event.data.options[type].forEach((data, id) => {
            createOptions(type, data, id + 1);
          });
        }
      }

      if (event.data.zones) {
        for (let i = 0; i < event.data.zones.length; i++) {
          event.data.zones[i].forEach((data, id) => {
            createOptions("zones", data, id + 1, i + 1);
          });
        }
      }

      if (isLocked && lockedX !== null && lockedY !== null) {
        optionsWrapper.style.left = lockedX;
        optionsWrapper.style.top = lockedY;
      } else {
        requestAnimationFrame(updateOptionsPosition);
      }
    }
  }
});
