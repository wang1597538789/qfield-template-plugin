import QtQuick

Item {
  signal prepareResult(var details)
  signal fetchResultsEnded()

  function fetchResults(searchString, context, parameters) {
    // 1. 动态获取已保存的 token
    const currentToken = parameters.apiKey;
    if (!currentToken || currentToken === "") {
      console.log("Error: Tianditu token is not set. Please configure it in the plugin settings.");
      fetchResultsEnded();
      return;
    }

    // 使用 context.mapExtent 动态设置搜索边界
    let mapBound = "73.0,3.0,135.0,53.0"; // 默认全国范围
    if (context && context.mapExtent) {
        mapBound = `${context.mapExtent.xMin},${context.mapExtent.yMin},${context.mapExtent.xMax},${context.mapExtent.yMax}`;
    }

    const postStr = {
      "keyWord": searchString,
      "level": 11,
      "mapBound": mapBound,
      "queryType": 1,
      "start": 0,
      "count": 10
    };

    // 2. Inject the dynamic token into the request URL.
    const url = "https://api.tianditu.gov.cn/search?type=query&postStr=" + encodeURIComponent(JSON.stringify(postStr)) + "&tk=" + currentToken;

    const xhr = new XMLHttpRequest();
    xhr.open("GET", url, true);
    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        try {
          // 仅在请求成功时处理响应
          if (xhr.status === 200) {
            const response = JSON.parse(xhr.responseText);
            if (response && response.pois && response.pois.length > 0) {
              for (let i = 0; i < response.pois.length; i++) {
                const poi = response.pois[i];
                const lonlat = poi.lonlat.split(",");
                if (lonlat.length === 2) { // 确保坐标数据有效
                    const result_details = {
                      "userData": { "lon": parseFloat(lonlat[0]), "lat": parseFloat(lonlat[1]) },
                      "displayString": poi.name,
                      "description": poi.address || "未知地址",
                      "score": 100 - i, // Higher score for top results
                      "group": qsTr("天地图在线搜索")
                    };
                    prepareResult(result_details);
                }
              }
            } else if (response && response.msg) {
                console.log("Tianditu API returned a message: " + response.msg);
            } else {
                console.log("Tianditu search returned no results for: " + searchString);
            }
          } else {
            // 如果请求失败，记录详细的错误信息
            console.log("Tianditu search request failed. Status: " + xhr.status + ", Response: " + xhr.responseText);
          }
        } catch(e) {
          console.log("Failed to process Tianditu response: " + e);
        }
        fetchResultsEnded(); // 关键：确保在请求完成后总是调用此信号
      }
    };
    xhr.send();
  }
}