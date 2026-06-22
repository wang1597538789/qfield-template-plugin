import QtQuick
import QtQuick.Controls

import org.qfield
import org.qgis
import Theme

Item {
  id: plugin

  property var mainWindow: iface.mainWindow()

  function openNavigation(lat, lng) {
    const coordText = lat.toFixed(6) + ', ' + lng.toFixed(6)

    if (Qt.platform.os === 'android') {
      // Android：geo URI 可唤起高德、百度、Google Maps 等已安装导航应用
      const geoUrl = 'geo:0,0?q=' + lat + ',' + lng + '(QField)'
      if (Qt.openUrlExternally(geoUrl)) {
        mainWindow.displayToast(qsTr('正在导航至画布中心: ') + coordText)
        return
      }
      // 回退：Google Maps 路线导航
      if (Qt.openUrlExternally('google.navigation:q=' + lat + ',' + lng)) {
        mainWindow.displayToast(qsTr('正在导航至画布中心: ') + coordText)
        return
      }
    } else if (Qt.platform.os === 'ios') {
      // iOS：Apple Maps 驾车导航
      if (Qt.openUrlExternally('maps://?daddr=' + lat + ',' + lng + '&dirflg=d')) {
        mainWindow.displayToast(qsTr('正在导航至画布中心: ') + coordText)
        return
      }
    } else {
      // 桌面或其他平台：Google Maps 网页版
      if (Qt.openUrlExternally('https://www.google.com/maps/dir/?api=1&destination=' + lat + ',' + lng + '&travelmode=driving')) {
        mainWindow.displayToast(qsTr('正在导航至画布中心: ') + coordText)
        return
      }
    }

    mainWindow.displayToast(qsTr('无法打开导航应用'))
  }

  Component.onCompleted: {
    iface.addItemToPluginsToolbar(pluginButton)
  }

  QfToolButton {
    id: pluginButton
    iconSource: 'icon.svg'
    iconColor: Theme.mainColor
    bgcolor: Theme.darkGray
    round: true

    onClicked: {
      const mapCanvas = iface.mapCanvas()
      const center = mapCanvas.mapSettings.getCenter(true)
      const wgs84Point = GeometryUtils.reprojectPointToWgs84(center, qgisProject.crs)
      const lat = wgs84Point.y
      const lng = wgs84Point.x

      openNavigation(lat, lng)
    }
  }
}
