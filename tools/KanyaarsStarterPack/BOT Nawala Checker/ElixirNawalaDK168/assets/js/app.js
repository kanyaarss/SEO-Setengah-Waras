import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

const FLASH_TIMEOUT_MS = 5000

const scheduleFlashRemoval = (el) => {
  if (!el || el.dataset.autoDismissScheduled === "true") return
  el.dataset.autoDismissScheduled = "true"

  window.setTimeout(() => {
    el.remove()
  }, FLASH_TIMEOUT_MS)
}

const wireFlashAutoDismiss = () => {
  document.querySelectorAll(".flash").forEach(scheduleFlashRemoval)

  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      mutation.addedNodes.forEach((node) => {
        if (!(node instanceof Element)) return

        if (node.matches(".flash")) {
          scheduleFlashRemoval(node)
          return
        }

        node.querySelectorAll?.(".flash").forEach(scheduleFlashRemoval)
      })
    })
  })

  observer.observe(document.body, {childList: true, subtree: true})
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})

wireFlashAutoDismiss()

liveSocket.connect()
window.liveSocket = liveSocket
