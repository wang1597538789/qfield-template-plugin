import QtQuick
import QtQuick.Controls

import org.qfield
import org.qgis
import QtCore
import Theme

Item {
  id: canvasNavPlugin

  property var mainWindow: iface.mainWindow()

  // 使用 Settings 组件以声明式方式管理插件的持久化配置
  Settings {
    id: wcpluginSettings
    category: "TiandituLocator" // 设置的分类，确保唯一性
    property string apiKey: ""   // 定义 apiKey 属性，默认值为空字符串
  }

  // 2. QField's configuration hook. This function is called when the user
  //    taps the settings (gear) icon for this plugin in QField's plugin manager.
  function configure() {
    tokenConfigDialog.open() // Open the settings dialog
  }

  // 3. The settings dialog UI
  Dialog {
    id: tokenConfigDialog
    parent: iface.mainWindow().contentItem
    anchors.centerIn: parent
    width: Math.min(parent.width * 0.85, 420)
    modal: true
    title: qsTr("天地图搜索插件设置")
    standardButtons: Dialog.Save | Dialog.Cancel

    Column {
      width: parent.width
      spacing: 12

      Label {
        text: qsTr("天地图 Web API 密钥 (tk):")
        font.bold: true
      }

      TextField {
        id: tokenInput
        width: parent.width
        placeholderText: qsTr("请在此处粘贴或输入您的密钥") // 绑定到 Settings 组件的 apiKey 属性
        text: wcpluginSettings.apiKey
        echoMode: TextInput.PasswordEchoOnEdit
      }

      Label {
        text: qsTr("温馨提示：密钥可在天地图开发者后台免费申请。")
        font.pixelSize: 11
        color: Theme.lightGray
      }
    }

    onAccepted: {
      // 当对话框确认时，将输入框中的值（去除前后空格）保存到设置中
      wcpluginSettings.apiKey = tokenInput.text.trim()
      mainWindow.displayToast(qsTr("✓ 天地图 Token 配置已保存"))
    }
  }

  // 导航确认对话框
  Dialog {
    id: navigationConfirmDialog
    parent: iface.mainWindow().contentItem
    anchors.centerIn: parent
    width: Math.min(parent.width * 0.85, 420)
    modal: true
    title: qsTr("导航确认")
    standardButtons: Dialog.Ok | Dialog.Cancel

    property real navLat
    property real navLng
    property string navLabel

    Column {
      width: parent.width
      spacing: 12

      Label {
        text: qsTr("目的地地址:")
        font.bold: true
      }

      // 使用只读的 TextArea 以便用户可以复制长地址
      TextArea {
        width: parent.width
        readOnly: true
        text: navigationConfirmDialog.navLabel
        wrapMode: Text.WordWrap
        selectByMouse: true
        background: null
        implicitHeight: contentHeight
      }
    }

    // 当用户点击 "OK" 按钮时触发
    onAccepted: {
      launchNavigationApp(navLat, navLng, navLabel)
    }
  }

  // 辅助函数：用于启动第三方导航应用
  function launchNavigationApp(lat, lng, label) {
    const coordText = lat.toFixed(6) + ', ' + lng.toFixed(6)
    const destinationLabel = label || 'QField'
    mainWindow.displayToast(qsTr("马上导航到%1").arg(destinationLabel))
    if (Qt.platform.os === 'android') {
      // Android：geo URI，将标签附加到坐标后面
      const geoUrl = 'geo:0,0?q=' + lat + ',' + lng + '(' + encodeURIComponent(destinationLabel) + ')'
      if (Qt.openUrlExternally(geoUrl)) {
        return
      }
      // 回退：Google Maps 路线导航 (不支持标签)
      if (Qt.openUrlExternally('google.navigation:q=' + lat + ',' + lng)) {
        return
      }
    } else if (Qt.platform.os === 'ios') {
      // iOS：Apple Maps，daddr 参数同时接受坐标和标签
      const appleMapsUrl = 'maps://?daddr=' + lat + ',' + lng + '&q=' + encodeURIComponent(destinationLabel)
      if (Qt.openUrlExternally(appleMapsUrl)) {
        return
      }
    } else {
      // 桌面或其他平台：Google Maps 网页版 (不支持标签)
      if (Qt.openUrlExternally('https://www.google.com/maps/dir/?api=1&destination=' + lat + ',' + lng + '&travelmode=driving')) {
        return
      }
    }

    mainWindow.displayToast(qsTr('无法打开导航应用'))
  }

  // 重写核心导航逻辑
  function openNavigation(lat, lng) {
    // 如果未配置 Token，直接使用默认标签打开确认对话框
    if (!wcpluginSettings.apiKey || wcpluginSettings.apiKey === "") {
      navigationConfirmDialog.navLat = lat
      navigationConfirmDialog.navLng = lng
      navigationConfirmDialog.navLabel = "目标点"
      navigationConfirmDialog.open()
      return
    }

    // 如果配置了 Token，则尝试通过逆地理编码获取地址
    const xhr = new XMLHttpRequest()
    const postStr = { "lon": lng, "lat": lat, "ver": 1 }
    const url = "https://api.tianditu.gov.cn/geocoder?postStr=" + encodeURIComponent(JSON.stringify(postStr)) + "&type=geocode&tk=" + wcpluginSettings.apiKey

    xhr.open("GET", url, true)
    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        let addressName = "目标点" // 设置回退的默认地址
        try {
          if (xhr.status === 200) {
            const response = JSON.parse(xhr.responseText)
            if (response && response.status === "0" && response.result) {
              addressName = response.result.formatted_address
            }
          }
        } catch(e) { console.log("解析天地图逆地理编码响应失败: " + e) }

        // 无论是否成功获取地址，都打开确认对话框
        navigationConfirmDialog.navLat = lat
        navigationConfirmDialog.navLng = lng
        navigationConfirmDialog.navLabel = addressName
        navigationConfirmDialog.open()
      }
    }
    xhr.send()
  }

  Component.onCompleted: {
    iface.addItemToPluginsToolbar(navigationButton)
  }

  QfToolButton {
    id: navigationButton
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

  // 4. The locator filter that integrates with QField's search bar
  QFieldLocatorFilter {
    id: tdtFilter
    name: "tianditu_locator"
    displayName: qsTr("天地图地址搜索")
    prefix: "tdt" // Users can type "tdt " to search only with this provider
    delay: 500 // Wait 500ms after user stops typing before searching
    locatorBridge: iface.findItemByObjectName('locatorBridge')
    parameters: { "apiKey": wcpluginSettings.apiKey }
    source: Qt.resolvedUrl('search.qml') // The background search logic

    // This function is called when a user selects a search result
    function triggerResult(result) {
      var wgsPoint = GeometryUtils.point(result.userData.lon, result.userData.lat);
      var projectedPoint = GeometryUtils.project(wgsPoint, "EPSG:4326", qgisProject.crs);
      iface.mapCanvas().center = projectedPoint;

      var geometryHighlighter = iface.findItemByObjectName('geometryHighlighter');
      if (geometryHighlighter) { geometryHighlighter.flashGeometry(wgsPoint, "EPSG:4326"); }

      iface.mainWindow().displayToast(qsTr("已定位至: ") + result.displayString);
    }
  }
}
