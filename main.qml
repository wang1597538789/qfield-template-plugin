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

  // 辅助函数：用于启动第三方导航应用
  function launchNavigationApp(lat, lng, label) {
    const coordText = lat.toFixed(6) + ', ' + lng.toFixed(6)
    const destinationLabel = label || 'QField'

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
    if (!wcpluginSettings.apiKey) {
      launchNavigationApp(lat, lng, "目标点");
      return;
    }

    // 如果配置了 Token，尝试获取地址
    var xhr = new XMLHttpRequest();
    var postStr = { "lon": lng, "lat": lat, "ver": 1 };
    var url = "https://api.tianditu.gov.cn/geocoder?postStr=" + encodeURIComponent(JSON.stringify(postStr)) + "&type=geocode&tk=" + wcpluginSettings.apiKey;

    xhr.open("GET", url, true);
    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        try {
          var response = JSON.parse(xhr.responseText);
          // 检查 API 是否成功返回地址
          if (xhr.status === 200 && response && response.status === "0" && response.result) {
            var addressName = response.result.formatted_address;
            Clipboard.setText(addressName);
            mainWindow.displayToast(qsTr("地址已复制: ") + addressName);
            launchNavigationApp(lat, lng, addressName); // 使用获取到的地址作为标签
            return;
          }
        } catch(e) { launchNavigationApp(lat, lng, "解析天地图逆地理编码响应失败: " + e);
        console.log("解析天地图逆地理编码响应失败: " + e); }

        // 如果请求或解析失败，则回退到默认行为
        launchNavigationApp(lat, lng, "目标点");
      }
    };
    xhr.send();
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
