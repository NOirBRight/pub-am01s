import QtQuick

// Menu summon lands here. The card itself stays on the service, so the gear and the menu share one window.
Item {
  property var service: null

  function open(payload) {
    if (service && service.openSettings)
      service.openSettings()
  }

  function close() {
    if (service && service.closeSettings)
      service.closeSettings()
  }
}
