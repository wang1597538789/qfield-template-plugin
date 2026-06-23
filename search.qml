import QtQuick
import Qt.labs.settings // Import the Settings module
import org.qfield

Item {
  signal prepareResult(var details)
  signal fetchResultsEnded()

  // A second Settings component. As long as the 'category' matches the one
  // in main.qml, it will read from the same persistent storage.
  Settings {
    id: bgSettings
    category: "TiandituLocator"
    readonly property string apiKey: "" // Read-only is enough here
  }

  function fetchResults(searchString, context, parameters) {
    // 1. Dynamically get the saved token.
    var currentToken = bgSettings.apiKey;
    if (!currentToken || currentToken === "") {
      console.log("Error: Tianditu token is not set. Please configure it in the plugin settings.");
      fetchResultsEnded();
      return;
    }

    var xhr = new XMLHttpRequest();
    var postStr = {
      "keyWord": searchString,
      "level": 11,
      "mapBound": "73.0,3.0,135.0,53.0",
      "queryType": 1,
      "start": 0,
      "count": 10
    };

    // 2. Inject the dynamic token into the request URL.
    var url = "https://api.tianditu.gov.cn/search?type=query&postStr=" + encodeURIComponent(JSON.stringify(postStr)) + "&tk=" + currentToken;

    xhr.open("GET", url, true);
    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        if (xhr.status === 200) {
          try {
            var response = JSON.parse(xhr.responseText);
            if (response && response.pois) {
              for (var i = 0; i < response.pois.length; i++) {
                var poi = response.pois[i];
                var lonlat = poi.lonlat.split(",");

                let result_details = {
                  "userData": { "lon": parseFloat(lonlat[0]), "lat": parseFloat(lonlat[1]) },
                  "displayString": poi.name,
                  "description": poi.address || "未知地址",
                  "score": 100 - i, // Higher score for top results
                  "group": qsTr("天地图在线搜索")
                };
                prepareResult(result_details);
              }
            }
          } catch(e) { console.log("Failed to parse Tianditu response: " + e); }
        }
        fetchResultsEnded();
      }
    };
    xhr.send();
  }
}